import Foundation

enum ArchipelagoAgentType: String, Codable, Sendable, CaseIterable {
    case claudeCode = "claude_code"
    case codex
    case openCode = "open_code"
    case gemini
    case openClaw = "open_claw"
    case cline
    case unknown

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = ArchipelagoAgentType(rawValue: value) ?? .unknown
    }

    static let agentHubMVPTypes: [ArchipelagoAgentType] = [.claudeCode, .codex, .gemini, .openCode]

    var isAgentHubMVPType: Bool {
        Self.agentHubMVPTypes.contains(self)
    }

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .openCode: return "OpenCode"
        case .gemini: return "Gemini"
        case .openClaw: return "OpenClaw"
        case .cline: return "Cline"
        case .unknown: return "Agent"
        }
    }

    var shortName: String {
        switch self {
        case .claudeCode: return "Claude"
        case .codex: return "Codex"
        case .openCode: return "OpenCode"
        case .gemini: return "Gemini CLI"
        case .openClaw: return "Claw"
        case .cline: return "Cline"
        case .unknown: return "?"
        }
    }

    var defaultGroupRole: String {
        switch self {
        case .claudeCode: return ArchipelagoGroupAgentRole.primary.rawValue
        case .codex: return ArchipelagoGroupAgentRole.reviewer.rawValue
        default: return ArchipelagoGroupAgentRole.coder.rawValue
        }
    }
}

enum ArchipelagoGroupAgentRole: String, CaseIterable, Identifiable, Sendable {
    case primary = "主 Agent"
    case coder = "Coder"
    case reviewer = "Reviewer"
    case planner = "Planner"

    var id: String { rawValue }
}

enum ArchipelagoCollaborationMode: String, Sendable {
    case mention
    case auto
}

struct ArchipelagoGroupMemberDraft: Equatable, Sendable {
    let agentType: ArchipelagoAgentType
    var role: String
}

struct ArchipelagoAgentInfo: Codable, Sendable, Identifiable {
    let agentType: ArchipelagoAgentType
    let name: String
    let description: String
    let available: Bool
    let enabled: Bool
    var id: String { agentType.rawValue }
}

enum ArchipelagoConnectionStatus: String, Codable, Sendable {
    case connecting, connected, prompting, disconnected, error

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = ArchipelagoConnectionStatus(rawValue: normalized) ?? .error
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct ArchipelagoConnectionInfo: Codable, Sendable, Identifiable {
    let id: String
    let agentType: ArchipelagoAgentType
    let status: ArchipelagoConnectionStatus
}

struct ArchipelagoConversation: Codable, Sendable, Identifiable {
    let id: String
    let title: String?
    let agentType: ArchipelagoAgentType
    let folderPath: String?
    let folderName: String?
    let startedAt: String?
    let endedAt: String?
    let messageCount: Int?
    let model: String?
    let gitBranch: String?
    var connectionId: String?
}

struct ArchipelagoDBConversationSummary: Codable, Sendable, Identifiable, Equatable {
    let id: Int
    let folderId: Int
    let title: String?
    let agentType: ArchipelagoAgentType
    let externalId: String?
    let messageCount: Int
}

struct ArchipelagoEventEnvelope: Codable, Sendable {
    let seq: Int
    let connectionId: String?
    let type: String
    private enum CodingKeys: String, CodingKey { case seq, type; case connectionId = "connection_id" }
}

struct ArchipelagoContentDelta: Codable, Sendable { let text: String }

struct ArchipelagoToolCall: Codable, Sendable, Identifiable {
    let toolCallId: String
    let title: String?
    let kind: String?
    let status: String?
    let content: String?
    let rawInput: String?
    let rawOutput: String?
    let meta: ArchipelagoToolCallMeta?
    var id: String { toolCallId }
    private enum CodingKeys: String, CodingKey {
        case toolCallId = "tool_call_id"
        case title, kind, status, content, meta
        case rawInput = "raw_input"
        case rawOutput = "raw_output"
    }
}

struct ArchipelagoToolCallMeta: Codable, Sendable {
    let delegation: ArchipelagoDelegationMeta?
    private enum CodingKeys: String, CodingKey { case delegation = "archipelago.delegation" }
}

struct ArchipelagoDelegationMeta: Codable, Sendable {
    let status: String?
    let childConnectionId: String?
    let childConversationId: Int?
    let errorCode: String?

    private enum CodingKeys: String, CodingKey {
        case status
        case childConnectionId = "child_connection_id"
        case childConversationId = "child_conversation_id"
        case errorCode = "error_code"
    }
}

struct ArchipelagoPermissionRequest: Codable, Sendable {
    let requestId: String
    let toolCall: PermissionToolCall?
    let options: [PermissionOption]
    struct PermissionToolCall: Codable, Sendable { let title: String? }
    struct PermissionOption: Codable, Sendable, Identifiable { let id: String; let label: String }
    private enum CodingKeys: String, CodingKey { case requestId = "request_id"; case toolCall = "tool_call"; case options }
}

struct ArchipelagoDelegationStarted: Decodable, Sendable {
    let childAgentType: ArchipelagoAgentType
    let childConnectionId: String?
    let childConversationId: Int?
    let parentConnectionId: String?
    let task: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        childAgentType = try container.decodeIfPresent(ArchipelagoAgentType.self, forKey: .childAgentType)
            ?? container.decodeIfPresent(ArchipelagoAgentType.self, forKey: .agentType)
            ?? .unknown
        childConnectionId = try container.decodeIfPresent(String.self, forKey: .childConnectionId)
        childConversationId = try container.decodeIfPresent(Int.self, forKey: .childConversationId)
        parentConnectionId = try container.decodeIfPresent(String.self, forKey: .parentConnectionId)
        task = try container.decodeIfPresent(String.self, forKey: .task)
    }

    private enum CodingKeys: String, CodingKey {
        case childAgentType = "child_agent_type"
        case agentType = "agent_type"
        case childConnectionId = "child_connection_id"
        case childConversationId = "child_conversation_id"
        case parentConnectionId = "parent_connection_id"
        case task
    }
}

struct ArchipelagoTurnComplete: Codable, Sendable {
    let stopReason: String?
    private enum CodingKeys: String, CodingKey { case stopReason = "stop_reason" }
}

struct ArchipelagoAttachRequest: Encodable {
    let action = "attach"
    let subscriptionId: String
    let connectionId: String
    let sinceSeq: Int?
    private enum CodingKeys: String, CodingKey { case action; case subscriptionId = "subscription_id"; case connectionId = "connection_id"; case sinceSeq = "since_seq" }
}

struct ArchipelagoDetachRequest: Encodable {
    let action = "detach"
    let subscriptionId: String
    private enum CodingKeys: String, CodingKey { case action; case subscriptionId = "subscription_id" }
}

struct ChatDisplayMessage: Identifiable, Equatable {
    let id: String
    let role: Role
    let agentType: ArchipelagoAgentType?
    var text: String
    var toolCalls: [ToolCallDisplay]
    var delegation: DelegationDisplay?
    var isStreaming: Bool
    enum Role: Equatable { case user, agent }
    struct ToolCallDisplay: Identifiable, Equatable {
        let id: String
        let title: String
        var status: String
        var content: String?
    }
    struct DelegationDisplay: Equatable {
        let childAgent: ArchipelagoAgentType
        let task: String
        var completed: Bool
    }
}

struct ArchipelagoFolder: Codable, Sendable {
    let id: Int
    let name: String
    let path: String
}

// MARK: - Archipelago Group Chat API

struct ArchipelagoGroupChatResponse: Codable, Sendable, Equatable {
    let group: GroupInfo
    let agents: [GroupAgentInfo]

    struct GroupInfo: Codable, Sendable, Equatable {
        let id: Int
        let name: String
        let folderId: Int?
        let folderPath: String?
        let primaryAgentId: Int?
        let createdAt: String
        let updatedAt: String
    }

    struct GroupAgentInfo: Codable, Sendable, Equatable {
        let id: Int
        let groupId: Int
        let agentType: ArchipelagoAgentType
        let role: String
        let conversationId: Int?
        let connectionId: String?
        let workingDir: String
        let createdAt: String
        let updatedAt: String
    }
}

struct ArchipelagoGroupDeletedPayload: Codable, Sendable {
    let groupId: Int?
    let folderId: Int?
}

struct ArchipelagoGroupAgentDeletedPayload: Codable, Sendable {
    let groupId: Int?
    let agentId: Int?
}

// MARK: - Preflight

struct ArchipelagoPreflightResult: Codable, Sendable {
    let passed: Bool
    let checks: [ArchipelagoCheckItem]
}

struct ArchipelagoCheckItem: Codable, Sendable, Identifiable {
    let name: String
    let passed: Bool
    let message: String?
    let details: String?
    var id: String { name }
}

struct ArchipelagoAgentStatus: Codable, Sendable {
    let agentType: ArchipelagoAgentType
    let available: Bool
    let enabled: Bool
    let installedVersion: String?
}

enum ArchipelagoError: LocalizedError {
    case httpError(String)
    case wsError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let message), .wsError(let message):
            let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Archipelago 请求失败。" : trimmed
        }
    }
}

// MARK: - Agent Display Status (UI-facing)

enum AgentDisplayStatus: String, Sendable {
    case working       // green — agent is prompting / actively working
    case idle          // gray — agent connected but idle
    case blocked       // orange — permission request pending
    case offline       // red/hidden — disconnected or error

    var overviewLabel: String {
        switch self {
        case .working:
            return "忙碌中"
        case .idle, .blocked, .offline:
            return "空闲中"
        }
    }
}

// MARK: - WebSocket Event Payloads

struct ArchipelagoStatusChangedPayload: Codable, Sendable {
    let status: ArchipelagoConnectionStatus
}

struct ArchipelagoTurnCompletePayload: Codable, Sendable {
    let stopReason: String?
    private enum CodingKeys: String, CodingKey { case stopReason = "stop_reason" }
}

struct ArchipelagoGroupCollaborationPlanPayload: Codable, Sendable {
    let groupId: Int
    let groupName: String
    let primaryAgentId: Int
    let requestedMentions: [String]
    let invalidMentions: [String]
    let members: [Member]

    struct Member: Codable, Sendable {
        let agentId: Int
        let agentType: ArchipelagoAgentType
        let role: String
        let workingDir: String
    }
}

struct ArchipelagoAgentTurnCompletion: Equatable, Sendable {
    let groupId: String
    let groupName: String
    let agentId: String
    let agentType: ArchipelagoAgentType
    let role: String
    let summary: String
}

struct ArchipelagoLiveSessionSnapshot: Codable, Sendable {
    let connectionId: String
    let conversationId: Int?
    let folderId: Int?
    let status: ArchipelagoConnectionStatus
    let pendingPermission: ArchipelagoPendingPermissionSnapshot?
}

struct ArchipelagoPendingPermissionSnapshot: Codable, Sendable {
    let requestId: String?
}

struct ArchipelagoSnapshotFrame: Codable, Sendable {
    let subscriptionId: String
    let connectionId: String
    let snapshot: ArchipelagoLiveSessionSnapshot
    let eventSeq: Int?
}

struct ArchipelagoConversationDetail: Codable, Sendable {
    let summary: ArchipelagoDBConversationSummary
    let turns: [ArchipelagoMessageTurn]

    var externalId: String? {
        summary.externalId?.nilIfBlank
    }

    var latestAssistantSummary: String? {
        turns.reversed().first(where: { $0.role == "assistant" })?.summaryText
    }
}

struct ArchipelagoMessageTurn: Codable, Sendable {
    let role: String
    let blocks: [ArchipelagoMessageBlock]

    var summaryText: String? {
        let text = blocks.compactMap(\.summaryText).joined(separator: "\n")
        return text.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
    }
}

struct ArchipelagoMessageBlock: Codable, Sendable {
    let type: String
    let text: String?
    let outputPreview: String?

    var summaryText: String? {
        switch type {
        case "text", "thinking":
            return text
        case "tool_result":
            return outputPreview
        default:
            return nil
        }
    }
}

// MARK: - Local Group Chat Model

struct GroupChat: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var primaryAgentId: String?
    var agents: [GroupAgent]
    let createdAt: Date
    var folderId: Int?
    var folderPath: String?
    var lastErrorMessage: String?

    var primaryAgent: GroupAgent? {
        if let primaryAgentId,
           let agent = agents.first(where: { $0.id == primaryAgentId }) {
            return agent
        }
        return agents.first(where: { $0.conversationId != nil }) ?? agents.first
    }

    var workspaceDisplayName: String {
        guard let folderPath else { return "No workspace" }
        return URL(fileURLWithPath: folderPath).lastPathComponent
    }

    var latestCompletedAgent: GroupAgent? {
        agents
            .filter { $0.latestResponseAt != nil }
            .max { lhs, rhs in
                (lhs.latestResponseAt ?? .distantPast) < (rhs.latestResponseAt ?? .distantPast)
            }
    }

    func archipelagoWorkspaceURL(baseURL: URL) -> URL? {
        guard let primaryAgent else {
            return nil
        }
        return archipelagoWorkspaceURL(baseURL: baseURL, agent: primaryAgent)
    }

    func archipelagoWorkspaceURL(baseURL: URL, agent: GroupAgent) -> URL? {
        guard agents.contains(where: { $0.id == agent.id }),
              let folderId,
              let conversationId = agent.conversationId else {
            return nil
        }
        var components = URLComponents(
            url: baseURL.appendingPathComponent("workspace"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "folderId", value: String(folderId)),
            URLQueryItem(name: "conversationId", value: String(conversationId)),
            URLQueryItem(name: "agent", value: agent.agentType.rawValue),
        ]
        return components?.url
    }

    struct GroupAgent: Identifiable, Equatable, Codable {
        let id: String
        let agentType: ArchipelagoAgentType
        var role: String = ArchipelagoGroupAgentRole.coder.rawValue
        var conversationId: Int?
        var connectionId: String?
        var status: ArchipelagoConnectionStatus
        var isBlocked: Bool = false
        var workingDir: String
        var latestResponseSummary: String?
        var latestResponseAt: Date?

        var displayStatus: AgentDisplayStatus {
            status == .prompting && !isBlocked ? .working : .idle
        }
    }
}

extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
