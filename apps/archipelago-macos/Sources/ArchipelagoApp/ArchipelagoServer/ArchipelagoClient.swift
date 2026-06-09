import Foundation

actor ArchipelagoClient {
    private let baseURL: URL
    private let token: String
    private let session = URLSession(configuration: .default)
    private let encoder = JSONEncoder()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    init(baseURL: URL, token: String) {
        self.baseURL = baseURL
        self.token = token
    }

    func listAgents() async throws -> [ArchipelagoAgentInfo] {
        try await post("acp_list_agents", body: EmptyBody())
    }

    func connect(agentType: ArchipelagoAgentType, workingDir: String?, sessionId: String? = nil) async throws -> String {
        struct Req: Encodable { let agentType: String; let workingDir: String?; let sessionId: String? }
        return try await post(
            "acp_connect",
            body: Req(agentType: agentType.rawValue, workingDir: workingDir, sessionId: sessionId)
        )
    }

    func disconnect(connectionId: String) async throws {
        struct Req: Encodable { let connectionId: String }
        let _: EmptyResponse? = try? await post("acp_disconnect", body: Req(connectionId: connectionId))
    }

    func prompt(
        connectionId: String,
        text: String,
        folderId: Int? = nil,
        conversationId: Int? = nil,
        collaborationMode: ArchipelagoCollaborationMode = .mention
    ) async throws {
        struct Block: Encodable { let type = "text"; let text: String }
        struct Req: Encodable {
            let connectionId: String
            let blocks: [Block]
            let folderId: Int?
            let conversationId: Int?
            let collaborationMode: String
        }
        let _: EmptyResponse? = try await post(
            "acp_prompt",
            body: Req(
                connectionId: connectionId,
                blocks: [Block(text: text)],
                folderId: folderId,
                conversationId: conversationId,
                collaborationMode: collaborationMode.rawValue
            )
        )
    }

    func cancel(connectionId: String) async throws {
        struct Req: Encodable { let connectionId: String }
        let _: EmptyResponse? = try? await post("acp_cancel", body: Req(connectionId: connectionId))
    }

    func respondPermission(connectionId: String, requestId: String, optionId: String) async throws {
        struct Req: Encodable { let connectionId: String; let requestId: String; let optionId: String }
        let _: EmptyResponse? = try? await post("acp_respond_permission", body: Req(connectionId: connectionId, requestId: requestId, optionId: optionId))
    }

    func listConnections() async throws -> [ArchipelagoConnectionInfo] {
        try await post("acp_list_connections", body: EmptyBody())
    }

    func listConversations() async throws -> [ArchipelagoConversation] {
        try await post("list_conversations", body: EmptyBody())
    }

    func listAllConversations(folderIds: [Int]? = nil) async throws -> [ArchipelagoDBConversationSummary] {
        struct Req: Encodable {
            let folderIds: [Int]?
            let agentType: String?
            let search: String?
            let sortBy: String?
            let status: String?
            let includeChildren: Bool?
        }
        return try await post(
            "list_all_conversations",
            body: Req(
                folderIds: folderIds,
                agentType: nil,
                search: nil,
                sortBy: nil,
                status: nil,
                includeChildren: false
            )
        )
    }

    func openFolder(path: String) async throws -> ArchipelagoFolder {
        struct Req: Encodable { let path: String }
        return try await post("open_folder", body: Req(path: path))
    }

    func removeFolderFromWorkspace(folderId: Int) async throws {
        struct Req: Encodable { let folderId: Int }
        let _: EmptyResponse? = try await post("remove_folder_from_workspace", body: Req(folderId: folderId))
    }

    func createConversation(folderId: Int, agentType: ArchipelagoAgentType, title: String?) async throws -> Int {
        struct Req: Encodable { let folderId: Int; let agentType: String; let title: String? }
        return try await post(
            "create_conversation",
            body: Req(folderId: folderId, agentType: agentType.rawValue, title: title)
        )
    }

    func updateConversationTitle(conversationId: Int, title: String) async throws {
        struct Req: Encodable { let conversationId: Int; let title: String }
        let _: EmptyResponse? = try await post(
            "update_conversation_title",
            body: Req(conversationId: conversationId, title: title)
        )
    }

    func deleteConversation(conversationId: Int) async throws {
        struct Req: Encodable { let conversationId: Int }
        let _: EmptyResponse? = try await post(
            "delete_conversation",
            body: Req(conversationId: conversationId)
        )
    }

    func preflight(agentType: ArchipelagoAgentType) async throws -> ArchipelagoPreflightResult {
        struct Req: Encodable { let agentType: String }
        return try await post("acp_preflight", body: Req(agentType: agentType.rawValue))
    }

    func getAgentStatus(agentType: ArchipelagoAgentType) async throws -> ArchipelagoAgentStatus {
        struct Req: Encodable { let agentType: String }
        return try await post("acp_get_agent_status", body: Req(agentType: agentType.rawValue))
    }

    func sessionSnapshot(conversationId: Int) async throws -> ArchipelagoLiveSessionSnapshot? {
        struct Req: Encodable { let conversationId: Int }
        return try await post(
            "acp_get_session_snapshot_by_conversation",
            body: Req(conversationId: conversationId)
        )
    }

    func conversationDetail(conversationId: Int) async throws -> ArchipelagoConversationDetail {
        struct Req: Encodable { let conversationId: Int }
        return try await post("get_folder_conversation", body: Req(conversationId: conversationId))
    }

    func listGroups() async throws -> [ArchipelagoGroupChatResponse] {
        try await post("list_groups", body: EmptyBody())
    }

    func createGroup(name: String, folderId: Int?, folderPath: String?) async throws -> ArchipelagoGroupChatResponse {
        struct Req: Encodable { let name: String; let folderId: Int?; let folderPath: String? }
        return try await post(
            "create_group",
            body: Req(name: name, folderId: folderId, folderPath: folderPath)
        )
    }

    func updateGroup(
        id: Int,
        name: String? = nil,
        primaryAgentId: Int? = nil
    ) async throws -> ArchipelagoGroupChatResponse {
        struct Req: Encodable {
            let id: Int
            let name: String?
            let primaryAgentId: Int?
        }
        return try await post(
            "update_group",
            body: Req(id: id, name: name, primaryAgentId: primaryAgentId)
        )
    }

    func deleteGroup(id: Int, folderId: Int?) async throws {
        struct Req: Encodable { let id: Int; let folderId: Int? }
        let _: EmptyResponse? = try await post("delete_group", body: Req(id: id, folderId: folderId))
    }

    func addGroupAgent(
        groupId: Int,
        agentType: ArchipelagoAgentType,
        role: String,
        conversationId: Int?,
        connectionId: String?,
        workingDir: String
    ) async throws -> ArchipelagoGroupChatResponse.GroupAgentInfo {
        struct Req: Encodable {
            let groupId: Int
            let agentType: String
            let role: String
            let conversationId: Int?
            let connectionId: String?
            let workingDir: String
        }
        return try await post(
            "add_group_agent",
            body: Req(
                groupId: groupId,
                agentType: agentType.rawValue,
                role: role,
                conversationId: conversationId,
                connectionId: connectionId,
                workingDir: workingDir
            )
        )
    }

    func removeGroupAgent(id: Int, groupId: Int?) async throws {
        struct Req: Encodable { let id: Int; let groupId: Int? }
        let _: EmptyResponse? = try await post("remove_group_agent", body: Req(id: id, groupId: groupId))
    }

    func updateGroupAgent(
        id: Int,
        role: String? = nil,
        connectionId: String? = nil,
        conversationId: Int? = nil
    ) async throws -> ArchipelagoGroupChatResponse.GroupAgentInfo {
        struct Req: Encodable {
            let id: Int
            let role: String?
            let connectionId: String?
            let conversationId: Int?
        }
        return try await post(
            "update_group_agent",
            body: Req(id: id, role: role, connectionId: connectionId, conversationId: conversationId)
        )
    }

    private struct EmptyBody: Encodable {}
    private struct EmptyResponse: Decodable {}

    private func post<Req: Encodable, Res: Decodable>(_ endpoint: String, body: Req) async throws -> Res {
        let url = baseURL.appendingPathComponent("api/\(endpoint)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(body)
        request.timeoutInterval = 60
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw ArchipelagoError.httpError(String(data: data, encoding: .utf8) ?? "unknown")
        }
        return try decoder.decode(Res.self, from: data)
    }
}
