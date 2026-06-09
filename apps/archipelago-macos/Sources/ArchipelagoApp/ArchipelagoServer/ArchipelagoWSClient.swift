import Foundation

struct ArchipelagoWSGlobalEventFrame: Equatable, Sendable {
    let channel: String
    let payload: Data
}

final class ArchipelagoWSClient: @unchecked Sendable {
    private let url: URL
    private let token: String
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let reconnectLock = NSLock()
    private var shouldReconnect = false

    var onEvent: (@Sendable (_ subscriptionId: String, _ eventType: String, _ rawJSON: Data) -> Void)?
    var onSnapshot: (@Sendable (_ subscriptionId: String, _ rawJSON: Data) -> Void)?
    var onDetached: (@Sendable (_ subscriptionId: String, _ reason: String) -> Void)?
    var onGlobalEvent: (@Sendable (_ channel: String, _ rawJSON: Data) -> Void)?

    init(baseURL: URL, token: String) {
        self.token = token
        var components = URLComponents(url: baseURL.appendingPathComponent("ws/events"), resolvingAgainstBaseURL: false)!
        components.scheme = baseURL.scheme == "https" ? "wss" : "ws"
        self.url = components.url!
        self.session = URLSession(configuration: .default)
    }

    func connect() {
        setShouldReconnect(true)
        var request = URLRequest(url: url)
        request.setValue(Self.webSocketProtocols(token: token), forHTTPHeaderField: "Sec-WebSocket-Protocol")
        let task = session.webSocketTask(with: request)
        self.task = task
        task.resume()
        receiveLoop()
    }

    func disconnect() {
        setShouldReconnect(false)
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func attach(subscriptionId: String, connectionId: String, sinceSeq: Int? = nil) {
        sendJSON(ArchipelagoAttachRequest(subscriptionId: subscriptionId, connectionId: connectionId, sinceSeq: sinceSeq))
    }

    func detach(subscriptionId: String) {
        sendJSON(ArchipelagoDetachRequest(subscriptionId: subscriptionId))
    }

    func ping() {
        struct Ping: Encodable { let action = "ping" }
        sendJSON(Ping())
    }

    private static func webSocketProtocols(token: String) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "archipelago-events" }
        let encoded = Data(trimmed.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
        return "archipelago-events, archipelago-token.\(encoded)"
    }

    private func sendJSON<T: Encodable>(_ value: T) {
        guard let data = try? encoder.encode(value), let text = String(data: data, encoding: .utf8) else { return }
        task?.send(.string(text)) { _ in }
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                if case .string(let text) = msg, let data = text.data(using: .utf8) { self.handleFrame(data) }
                self.receiveLoop()
            case .failure:
                guard self.canReconnect else { return }
                DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self, self.canReconnect else { return }
                    self.connect()
                }
            }
        }
    }

    private var canReconnect: Bool {
        reconnectLock.lock()
        defer { reconnectLock.unlock() }
        return shouldReconnect
    }

    private func setShouldReconnect(_ value: Bool) {
        reconnectLock.lock()
        shouldReconnect = value
        reconnectLock.unlock()
    }

    private func handleFrame(_ data: Data) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        if let frame = Self.decodeGlobalEventFrame(json) {
            onGlobalEvent?(frame.channel, frame.payload)
            return
        }
        guard let type = json["type"] as? String else { return }
        switch type {
        case "snapshot":
            if let subId = json["subscription_id"] as? String { onSnapshot?(subId, data) }
        case "event":
            if let subId = json["subscription_id"] as? String,
               let envelope = json["envelope"] as? [String: Any],
               let eventType = envelope["type"] as? String,
               let envelopeData = try? JSONSerialization.data(withJSONObject: envelope) {
                onEvent?(subId, eventType, envelopeData)
            }
        case "detached":
            if let subId = json["subscription_id"] as? String, let reason = json["reason"] as? String {
                onDetached?(subId, reason)
            }
        default: break
        }
    }

    static func decodeGlobalEventFrame(_ json: [String: Any]) -> ArchipelagoWSGlobalEventFrame? {
        guard let channel = json["channel"] as? String else { return nil }
        let payload = json["payload"] ?? [:]
        guard JSONSerialization.isValidJSONObject(payload),
              let payloadData = try? JSONSerialization.data(withJSONObject: payload) else {
            return nil
        }
        return ArchipelagoWSGlobalEventFrame(channel: channel, payload: payloadData)
    }
}
