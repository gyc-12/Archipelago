import AppKit
import Foundation
import Network
import Observation

enum ArchipelagoHealthProbeResult: Equatable {
    case healthy
    case unauthorized
    case httpStatus(Int)
    case unreachable
}

enum ArchipelagoServerStartupFailure: Equatable {
    case embeddedHelperMissing(String?)
    case embeddedStaticAssetsMissing(String?)
    case dataDirectoryCreationFailed(String)
    case embeddedLaunchFailed(String)
    case embeddedHealthTimeout
    case embeddedProcessExited(Int32)
    case embeddedPortUnavailable(UInt16, Int?)
    case embeddedTokenMismatch(UInt16)
    case externalAppMissing(String)
    case externalLaunchFailed(String)
    case externalHealthTimeout

    var message: String {
        switch self {
        case .embeddedHelperMissing(let path):
            if let path, !path.isEmpty {
                return "包内 Archipelago Server 不可执行: \(path)"
            }
            return "包内缺少 Archipelago Server helper。请重新打包或安装完整的 Archipelago.app。"
        case .embeddedStaticAssetsMissing(let path):
            if let path, !path.isEmpty {
                return "包内 Archipelago Web 静态资源缺少 index.html: \(path)"
            }
            return "包内缺少 Archipelago Web 静态资源。请重新打包或安装完整的 Archipelago.app。"
        case .dataDirectoryCreationFailed(let reason):
            return "无法创建 Archipelago Server 数据目录: \(reason)"
        case .embeddedLaunchFailed(let reason):
            return "内嵌 Archipelago Server 启动失败: \(reason)"
        case .embeddedHealthTimeout:
            return "内嵌 Archipelago Server 已启动，但健康检查超时。"
        case .embeddedProcessExited(let status):
            return "内嵌 Archipelago Server 已退出，状态码 \(status)。"
        case .embeddedPortUnavailable(let port, let statusCode):
            if let statusCode {
                return "端口 \(port) 已被其他服务占用，Archipelago Server 健康检查返回 HTTP \(statusCode)。请关闭占用进程后重试，或设置 \(ArchipelagoEmbeddedRuntimeConfig.portEnvKey) 使用其他端口。"
            }
            return "端口 \(port) 已被其他服务占用。请关闭占用进程后重试，或设置 \(ArchipelagoEmbeddedRuntimeConfig.portEnvKey) 使用其他端口。"
        case .embeddedTokenMismatch(let port):
            return "端口 \(port) 上已有 Archipelago Server 服务，但 token 与当前 Archipelago 不匹配。请关闭旧服务后重试，或使用同一个 Archipelago 内嵌 token。"
        case .externalAppMissing(let path):
            return "开发 fallback 已启用，但未找到外部 Archipelago Web.app: \(path)"
        case .externalLaunchFailed(let reason):
            return "外部 Archipelago Web.app 启动失败: \(reason)"
        case .externalHealthTimeout:
            return "外部 Archipelago Web.app 已启动，但健康检查超时。"
        }
    }
}

private final class TCPPortProbeState: @unchecked Sendable {
    private let continuation: CheckedContinuation<Bool, Never>
    private let lock = NSLock()
    private var didResume = false
    private var connection: NWConnection?

    init(continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func setConnection(_ connection: NWConnection) {
        lock.lock()
        self.connection = connection
        lock.unlock()
    }

    func finish(_ result: Bool) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        let connection = self.connection
        lock.unlock()

        connection?.cancel()
        continuation.resume(returning: result)
    }
}

@MainActor
@Observable
final class ArchipelagoServerManager {
    static let externalFallbackEnvKey = "ARCHIPELAGO_SERVER_EXTERNAL_FALLBACK"
    private static let automaticFallbackPortRange: ClosedRange<UInt16> = 3080...3099

    private(set) var isRunning = false
    private(set) var port: UInt16 = 3079
    private(set) var isUsingEmbeddedServer = false
    private(set) var lastFailure: ArchipelagoServerStartupFailure?

    var appPath: String
    var embeddedConfig: ArchipelagoEmbeddedRuntimeConfig
    let allowsExternalFallback: Bool
    let allowsAutomaticPortFallback: Bool
    private var embeddedProcess: Process?

    init(
        appPath: String = "/Applications/Archipelago Web.app",
        embeddedConfig: ArchipelagoEmbeddedRuntimeConfig = ArchipelagoEmbeddedRuntimeConfig(),
        allowsExternalFallback: Bool = ArchipelagoServerManager.defaultAllowsExternalFallback(),
        allowsAutomaticPortFallback: Bool = ArchipelagoServerManager.defaultAllowsAutomaticPortFallback()
    ) {
        self.appPath = appPath
        self.embeddedConfig = embeddedConfig
        self.allowsExternalFallback = allowsExternalFallback
        self.allowsAutomaticPortFallback = allowsAutomaticPortFallback
        self.port = embeddedConfig.port
    }

    var baseURL: URL { URL(string: "http://127.0.0.1:\(port)")! }

    static func defaultAllowsExternalFallback(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let raw = environment[externalFallbackEnvKey] else { return false }
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }

    static func defaultAllowsAutomaticPortFallback(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        !ArchipelagoEmbeddedRuntimeConfig.hasExplicitPortOverride(environment: environment)
    }

    static func fallbackPortCandidates(preferredPort: UInt16) -> [UInt16] {
        automaticFallbackPortRange.filter { $0 != preferredPort }
    }

    /// Launches the embedded Archipelago Server. The external app fallback is dev-only and must be explicitly enabled.
    /// Returns true if Archipelago Server was launched (or was already running and healthy).
    func start(token: String) async -> Bool {
        guard !isRunning else { return true }
        lastFailure = nil

        // Check if already reachable before attempting launch.
        let existingProbe = await probeHealth(token: token)
        if existingProbe == .healthy {
            isRunning = true
            return true
        }
        let portOpen = existingProbe == .unreachable ? await isTCPPortOpen() : false
        if let failure = Self.startupFailureForExistingService(existingProbe, port: port, isTCPPortOpen: portOpen) {
            guard allowsAutomaticPortFallback, let fallbackPort = await firstAvailableFallbackPort() else {
                lastFailure = failure
                return false
            }
            NSLog("[ArchipelagoServerManager] port %d unavailable; retrying embedded Archipelago Server on %d", port, fallbackPort)
            embeddedConfig = embeddedConfig.withPort(fallbackPort)
            port = fallbackPort
        }

        if await startEmbeddedServer() {
            let ready = await waitForReady(token: embeddedConfig.token)
            isRunning = ready
            isUsingEmbeddedServer = ready
            if ready { return true }
            if let process = embeddedProcess, !process.isRunning {
                lastFailure = .embeddedProcessExited(process.terminationStatus)
            } else if lastFailure == nil {
                lastFailure = .embeddedHealthTimeout
            }
            stopEmbeddedServer()
        }

        guard allowsExternalFallback else { return false }
        return await startExternalApp(token: token)
    }

    static func startupFailureForExistingService(
        _ probe: ArchipelagoHealthProbeResult,
        port: UInt16,
        isTCPPortOpen: Bool
    ) -> ArchipelagoServerStartupFailure? {
        switch probe {
        case .healthy:
            return nil
        case .unauthorized:
            return .embeddedTokenMismatch(port)
        case .httpStatus(let statusCode):
            return .embeddedPortUnavailable(port, statusCode)
        case .unreachable:
            return isTCPPortOpen ? .embeddedPortUnavailable(port, nil) : nil
        }
    }

    func stop() {
        stopEmbeddedServer()
        isRunning = false
        isUsingEmbeddedServer = false
    }

    func waitForReady(token: String) async -> Bool {
        for _ in 0..<30 {
            try? await Task.sleep(for: .milliseconds(500))
            if await probeHealth(token: token) == .healthy { return true }
        }
        return false
    }

    private func startEmbeddedServer() async -> Bool {
        guard let serverURL = embeddedConfig.serverURL, FileManager.default.isExecutableFile(atPath: serverURL.path) else {
            NSLog("[ArchipelagoServerManager] embedded Archipelago Server not available")
            lastFailure = .embeddedHelperMissing(embeddedConfig.serverURL?.path)
            return false
        }
        guard embeddedConfig.staticAssetsAvailable else {
            NSLog("[ArchipelagoServerManager] embedded Archipelago Web assets not available")
            lastFailure = .embeddedStaticAssetsMissing(embeddedConfig.staticDirectoryURL?.path)
            return false
        }

        do {
            try FileManager.default.createDirectory(
                at: embeddedConfig.dataDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog("[ArchipelagoServerManager] failed to create embedded Archipelago Server data dir: %@", error.localizedDescription)
            lastFailure = .dataDirectoryCreationFailed(error.localizedDescription)
            return false
        }

        let process = Process()
        process.executableURL = serverURL
        process.environment = embeddedConfig.environment
        process.standardOutput = FileHandle(forWritingAtPath: "/dev/null")
        process.standardError = FileHandle(forWritingAtPath: "/dev/null")
        process.terminationHandler = { [weak self] process in
            NSLog("[ArchipelagoServerManager] embedded Archipelago Server exited with status %d", process.terminationStatus)
            Task { @MainActor [weak self] in
                guard let self, self.embeddedProcess === process else { return }
                self.isRunning = false
                self.isUsingEmbeddedServer = false
                self.lastFailure = .embeddedProcessExited(process.terminationStatus)
            }
        }

        do {
            try process.run()
            embeddedProcess = process
            port = embeddedConfig.port
            NSLog("[ArchipelagoServerManager] launched embedded Archipelago Server")
            return true
        } catch {
            NSLog("[ArchipelagoServerManager] failed to launch embedded Archipelago Server: %@", error.localizedDescription)
            lastFailure = .embeddedLaunchFailed(error.localizedDescription)
            return false
        }
    }

    private func stopEmbeddedServer() {
        if let process = embeddedProcess, process.isRunning {
            process.terminate()
        }
        embeddedProcess = nil
    }

    private func startExternalApp(token: String) async -> Bool {
        // Launch the .app bundle
        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appPath) else {
            NSLog("[ArchipelagoServerManager] app not found at: %@", appPath)
            lastFailure = .externalAppMissing(appPath)
            return false
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        do {
            _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
            NSLog("[ArchipelagoServerManager] launched Archipelago Web app at: %@", appPath)
        } catch {
            NSLog("[ArchipelagoServerManager] failed to launch app: %@", error.localizedDescription)
            lastFailure = .externalLaunchFailed(error.localizedDescription)
            return false
        }

        // Wait for app to become healthy
        let ready = await waitForReady(token: token)
        isRunning = ready
        isUsingEmbeddedServer = false
        if !ready {
            lastFailure = .externalHealthTimeout
        }
        return ready
    }

    private func probeHealth(token: String) async -> ArchipelagoHealthProbeResult {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/health"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        request.timeoutInterval = 5
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else { return .unreachable }
        if (200...299).contains(http.statusCode) { return .healthy }
        if http.statusCode == 401 { return .unauthorized }
        return .httpStatus(http.statusCode)
    }

    private func firstAvailableFallbackPort() async -> UInt16? {
        for candidate in Self.fallbackPortCandidates(preferredPort: port) where !(await isTCPPortOpen(candidate)) {
            return candidate
        }
        return nil
    }

    private func isTCPPortOpen(_ port: UInt16? = nil) async -> Bool {
        let port = port ?? self.port
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return false }
        return await withCheckedContinuation { continuation in
            let state = TCPPortProbeState(continuation: continuation)
            let connection = NWConnection(host: "127.0.0.1", port: nwPort, using: .tcp)
            state.setConnection(connection)

            connection.stateUpdateHandler = { connectionState in
                switch connectionState {
                case .ready:
                    state.finish(true)
                case .failed, .cancelled:
                    state.finish(false)
                default:
                    break
                }
            }
            connection.start(queue: .global(qos: .utility))
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.75) {
                state.finish(false)
            }
        }
    }
}
