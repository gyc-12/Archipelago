import Foundation

struct ArchipelagoEmbeddedRuntimeConfig: Equatable {
    static let serverPathEnvKey = "ARCHIPELAGO_SERVER_PATH"
    static let staticDirEnvKey = "ARCHIPELAGO_SERVER_STATIC_DIR"
    static let dataDirEnvKey = "ARCHIPELAGO_SERVER_DATA_DIR"
    static let hostEnvKey = "ARCHIPELAGO_SERVER_HOST"
    static let portEnvKey = "ARCHIPELAGO_SERVER_PORT"
    static let tokenEnvKey = "ARCHIPELAGO_SERVER_TOKEN"
    static let tokenDefaultsKey = "archipelago.server.embeddedToken"

    let serverURL: URL?
    let staticDirectoryURL: URL?
    let dataDirectoryURL: URL
    let bindHost: String
    let port: UInt16
    let token: String

    var isAvailable: Bool {
        guard let serverURL else { return false }
        return FileManager.default.isExecutableFile(atPath: serverURL.path)
    }

    var staticAssetsAvailable: Bool {
        guard let staticDirectoryURL else { return false }
        return FileManager.default.fileExists(
            atPath: staticDirectoryURL.appendingPathComponent("index.html").path
        )
    }

    var environment: [String: String] {
        var values = Self.sanitizedServerEnvironment(from: ProcessInfo.processInfo.environment)
        values["ARCHIPELAGO_HOST"] = bindHost
        values["ARCHIPELAGO_PORT"] = String(port)
        values["ARCHIPELAGO_TOKEN"] = token
        values["ARCHIPELAGO_DATA_DIR"] = dataDirectoryURL.path
        if let staticDirectoryURL {
            values["ARCHIPELAGO_STATIC_DIR"] = staticDirectoryURL.path
        }
        return values
    }

    static func sanitizedServerEnvironment(from environment: [String: String]) -> [String: String] {
        environment.filter { entry in
            !isInheritedProviderEnvironmentKey(entry.key)
        }
    }

    private static func isInheritedProviderEnvironmentKey(_ key: String) -> Bool {
        let exactKeys: Set<String> = [
            "GOOGLE_API_KEY",
        ]
        if exactKeys.contains(key) { return true }

        return key.hasPrefix("OPENAI_")
            || key.hasPrefix("ANTHROPIC_")
            || key.hasPrefix("GEMINI_")
            || key.hasPrefix("GOOGLE_GEMINI_")
    }

    init(
        serverURL: URL? = Self.defaultServerURL(),
        staticDirectoryURL: URL? = Self.defaultStaticDirectoryURL(),
        dataDirectoryURL: URL = Self.defaultDataDirectoryURL(),
        bindHost: String = Self.defaultBindHost(),
        port: UInt16 = Self.defaultPort(),
        token: String = Self.defaultToken()
    ) {
        self.serverURL = serverURL
        self.staticDirectoryURL = staticDirectoryURL
        self.dataDirectoryURL = dataDirectoryURL
        self.bindHost = bindHost
        self.port = port
        self.token = token
    }

    static func defaultServerURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let override = envValue(environment, serverPathEnvKey) {
            return URL(fileURLWithPath: override)
        }

        let bundleHelper = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent("archipelago-server")
        if FileManager.default.fileExists(atPath: bundleHelper.path) {
            return bundleHelper
        }

        return nil
    }

    static func defaultStaticDirectoryURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL? {
        if let override = envValue(environment, staticDirEnvKey) {
            return URL(fileURLWithPath: override)
        }

        let bundled = Bundle.main.resourceURL?.appendingPathComponent("ArchipelagoWeb")
        if let bundled, FileManager.default.fileExists(atPath: bundled.appendingPathComponent("index.html").path) {
            return bundled
        }

        return nil
    }

    static func defaultDataDirectoryURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let override = envValue(environment, dataDirEnvKey) {
            return URL(fileURLWithPath: override)
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Archipelago", isDirectory: true)
            .appendingPathComponent("Server", isDirectory: true)
    }

    func withPort(_ port: UInt16) -> ArchipelagoEmbeddedRuntimeConfig {
        ArchipelagoEmbeddedRuntimeConfig(
            serverURL: serverURL,
            staticDirectoryURL: staticDirectoryURL,
            dataDirectoryURL: dataDirectoryURL,
            bindHost: bindHost,
            port: port,
            token: token
        )
    }

    static func defaultBindHost(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let trimmed = envValue(environment, hostEnvKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "0.0.0.0" : trimmed
    }

    static func hasExplicitPortOverride(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        guard let raw = envValue(environment, portEnvKey),
              let port = UInt16(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              port > 0 else {
            return false
        }
        return true
    }

    static func defaultPort(environment: [String: String] = ProcessInfo.processInfo.environment) -> UInt16 {
        guard let raw = envValue(environment, portEnvKey),
              let port = UInt16(raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              port > 0 else {
            return 3079
        }
        return port
    }

    static func defaultToken(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        defaults: UserDefaults = .standard
    ) -> String {
        if let override = envValue(environment, tokenEnvKey),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return loadOrCreateToken(defaults: defaults)
    }

    static func loadOrCreateToken(defaults: UserDefaults = .standard) -> String {
        if let saved = defaults.string(forKey: tokenDefaultsKey),
           !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return saved
        }
        let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        defaults.set(token, forKey: tokenDefaultsKey)
        return token
    }

    private static func envValue(_ environment: [String: String], _ key: String) -> String? {
        if let value = environment[key], !value.isEmpty {
            return value
        }
        return nil
    }
}
