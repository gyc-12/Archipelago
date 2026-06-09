import AppKit
import WebKit

@MainActor
final class ChatWindowController: NSObject, WKUIDelegate {
    private enum WindowKey {
        static let archipelagoDirect = "__archipelago__"
        static let archipelagoSettings = "__archipelago_settings__"
    }

    private struct ArchipelagoWebViewContext {
        let baseURL: URL
        let token: String
    }

    private var windows: [String: NSWindow] = [:]
    private var webViews: [String: WKWebView] = [:]
    private var webViewContexts: [ObjectIdentifier: ArchipelagoWebViewContext] = [:]

    func openGroupChat(group: GroupChat, coordinator: ArchipelagoCoordinator) {
        openGroupChat(
            group: group,
            url: coordinator.archipelagoWorkspaceURL(for: group) ?? coordinator.archipelagoBaseURL,
            coordinator: coordinator
        )
    }

    func openGroupChat(
        group: GroupChat,
        agent: GroupChat.GroupAgent,
        coordinator: ArchipelagoCoordinator
    ) {
        guard let url = coordinator.archipelagoWorkspaceURL(for: group, agent: agent) else {
            return
        }
        openGroupChat(group: group, url: url, coordinator: coordinator)
    }

    private func openGroupChat(group: GroupChat, url: URL, coordinator: ArchipelagoCoordinator) {
        let key = group.id
        if let existing = windows[key] {
            if let webView = webViews[key] {
                updateContext(for: webView, coordinator: coordinator)
            }
            if let webView = webViews[key] {
                webView.load(URLRequest(url: url))
            }
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let webView = createWebView(coordinator: coordinator)
        webView.load(URLRequest(url: url))

        let window = makeWindow(title: "Archipelago · \(group.name)", webView: webView)
        windows[key] = window
        webViews[key] = webView
    }

    func openArchipelagoDirect(coordinator: ArchipelagoCoordinator) {
        let key = WindowKey.archipelagoDirect
        if let existing = windows[key] {
            if let webView = webViews[key] {
                updateContext(for: webView, coordinator: coordinator)
            }
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let webView = createWebView(coordinator: coordinator)
        webView.load(URLRequest(url: coordinator.archipelagoBaseURL))

        let window = makeWindow(title: "Archipelago Web", webView: webView)
        windows[key] = window
        webViews[key] = webView
    }

    func closeAll() {
        windows.values.forEach { $0.close() }
        windows.removeAll()
        webViews.removeAll()
        webViewContexts.removeAll()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let context = webViewContexts[ObjectIdentifier(webView)] else {
            return nil
        }

        switch ArchipelagoWebWindowRouter.target(for: navigationAction.request.url, baseURL: context.baseURL) {
        case .archipelagoSettings(let url):
            openArchipelagoSettings(url: url, context: context)
        case .external(let url):
            NSWorkspace.shared.open(url)
        case .ignore:
            break
        }

        return nil
    }

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping @MainActor @Sendable ([URL]?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = parameters.allowsMultipleSelection
        panel.canChooseDirectories = parameters.allowsDirectories
        panel.canChooseFiles = !parameters.allowsDirectories
        panel.canCreateDirectories = false
        panel.message = parameters.allowsDirectories ? "选择要附加的文件夹" : "选择要附加的文件"
        panel.prompt = "选择"

        if let window = webView.window {
            panel.beginSheetModal(for: window) { response in
                completionHandler(response == .OK ? panel.urls : nil)
            }
        } else {
            completionHandler(panel.runModal() == .OK ? panel.urls : nil)
        }
    }

    // MARK: - Private

    private func createWebView(coordinator: ArchipelagoCoordinator) -> WKWebView {
        createWebView(
            context: ArchipelagoWebViewContext(
                baseURL: coordinator.archipelagoBaseURL,
                token: coordinator.archipelagoToken
            )
        )
    }

    private func createWebView(context: ArchipelagoWebViewContext) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")
        config.userContentController.addUserScript(
            WKUserScript(
                source: """
                localStorage.setItem('archipelago_token', \(Self.javascriptStringLiteral(context.token)));
                localStorage.setItem('archipelago_island_embedded', 'true');
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            )
        )
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = self
        webViewContexts[ObjectIdentifier(webView)] = context
        return webView
    }

    private func updateContext(for webView: WKWebView, coordinator: ArchipelagoCoordinator) {
        webViewContexts[ObjectIdentifier(webView)] = ArchipelagoWebViewContext(
            baseURL: coordinator.archipelagoBaseURL,
            token: coordinator.archipelagoToken
        )
    }

    private func openArchipelagoSettings(url: URL, context: ArchipelagoWebViewContext) {
        let key = WindowKey.archipelagoSettings
        if let existing = windows[key],
           let webView = webViews[key] {
            webViewContexts[ObjectIdentifier(webView)] = context
            webView.load(URLRequest(url: url))
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let webView = createWebView(context: context)
        webView.load(URLRequest(url: url))

        let window = makeWindow(title: "Archipelago Settings", webView: webView)
        windows[key] = window
        webViews[key] = webView
    }

    private static func javascriptStringLiteral(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let literal = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return literal
    }

    private func makeWindow(title: String, webView: WKWebView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = webView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        return window
    }
}

enum ArchipelagoWebWindowTarget: Equatable {
    case archipelagoSettings(URL)
    case external(URL)
    case ignore
}

enum ArchipelagoWebWindowRouter {
    static func target(for requestedURL: URL?, baseURL: URL) -> ArchipelagoWebWindowTarget {
        guard let requestedURL,
              let resolvedURL = resolve(requestedURL, against: baseURL) else {
            return .ignore
        }

        if isSameOrigin(resolvedURL, baseURL),
           isSettingsPath(resolvedURL.path) {
            return .archipelagoSettings(resolvedURL)
        }

        if canOpenExternally(resolvedURL) {
            return .external(resolvedURL)
        }

        return .ignore
    }

    private static func resolve(_ url: URL, against baseURL: URL) -> URL? {
        if url.scheme == nil {
            return URL(string: url.relativeString, relativeTo: baseURL)?.absoluteURL
        }
        return url
    }

    private static func isSameOrigin(_ lhs: URL, _ rhs: URL) -> Bool {
        lhs.scheme?.lowercased() == rhs.scheme?.lowercased()
            && lhs.host?.lowercased() == rhs.host?.lowercased()
            && normalizedPort(lhs) == normalizedPort(rhs)
    }

    private static func normalizedPort(_ url: URL) -> Int? {
        if let port = url.port {
            return port
        }
        switch url.scheme?.lowercased() {
        case "http": return 80
        case "https": return 443
        default: return nil
        }
    }

    private static func isSettingsPath(_ path: String) -> Bool {
        path == "/settings" || path.hasPrefix("/settings/")
    }

    private static func canOpenExternally(_ url: URL) -> Bool {
        switch url.scheme?.lowercased() {
        case "http", "https", "mailto": return true
        default: return false
        }
    }
}
