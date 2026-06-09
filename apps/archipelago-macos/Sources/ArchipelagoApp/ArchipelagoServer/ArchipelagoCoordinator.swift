import AppKit
import Foundation
import Observation

enum ArchipelagoContentState: Equatable {
    case chatList
    case createChat
    case addAgents(groupId: String)
    case groupDetail(groupId: String)
}

private enum ArchipelagoGroupTaskSendError: LocalizedError {
    case missingGroup
    case missingPrimaryAgent
    case missingFolder
    case missingConversation
    case malformedAgentId
    case archipelagoDisconnected
    case primaryConnectionNotReady(ArchipelagoConnectionStatus)
    case primaryConnectionTimeout

    var errorDescription: String? {
        switch self {
        case .missingGroup:
            return "群聊不存在。"
        case .missingPrimaryAgent:
            return "群聊还没有主 Agent。"
        case .missingFolder:
            return "群聊还没有绑定 Archipelago 工作区。"
        case .missingConversation:
            return "主 Agent 还没有绑定 Archipelago 会话。"
        case .malformedAgentId:
            return "主 Agent 标识无效。"
        case .archipelagoDisconnected:
            return "内嵌 Archipelago 服务未连接。"
        case .primaryConnectionNotReady(let status):
            return "主 Agent 连接未就绪，当前状态为 \(status.rawValue)。"
        case .primaryConnectionTimeout:
            return "主 Agent 连接超时，请稍后重试。"
        }
    }
}

@MainActor
@Observable
final class ArchipelagoCoordinator {
    private static let defaultTokenKey = "archipelago.token"

    let serverManager: ArchipelagoServerManager
    private let groupStore: ArchipelagoGroupChatStore
    private let webServiceConfigReader: ArchipelagoWebServiceConfigReader
    private(set) var client: ArchipelagoClient?
    private(set) var wsClient: ArchipelagoWSClient?
    private var activeToken: String?

    var contentState: ArchipelagoContentState = .chatList
    private(set) var availableAgents: [ArchipelagoAgentInfo] = []
    private(set) var isLoading = true
    private(set) var isArchipelagoConnected = false
    private(set) var connectionErrorMessage: String?

    private(set) var groupChats: [GroupChat] = []

    /// Maps connectionId → subscriptionId for active WebSocket subscriptions
    private var subscriptions: [String: String] = [:]
    private var responseTextByConnection: [String: String] = [:]
    private var collaborationMemberIdsByPrimaryConnection: [String: Set<String>] = [:]
    private var childConnectionToPrimaryConnection: [String: String] = [:]
    private var delegatedConversationIdByChildConnection: [String: Int] = [:]
    private var previousConnectionIdByChildConnection: [String: String] = [:]
    private var delegationPrimaryConnectionByToolCallId: [String: String] = [:]
    private var delegationAgentTypeByToolCallId: [String: ArchipelagoAgentType] = [:]
    private var delegationTaskByToolCallId: [String: String] = [:]
    private var delegationChildConnectionByToolCallId: [String: String] = [:]
    private var groupRuntimeSyncTask: Task<Void, Never>?
    private var groupListSyncTask: Task<Void, Never>?
    private var isReconcilingGroupConversationBindings = false
    private var sendingGroupTaskIds: Set<String> = []
    @ObservationIgnored var onGroupChatsChanged: (() -> Void)?
    @ObservationIgnored var onAgentTurnCompleted: ((ArchipelagoAgentTurnCompletion) -> Void)?

    var selectedFolderURL: URL?
    var isCreating = false
    var creationErrorMessage: String?

    /// Optional development token override used only when external Archipelago fallback is explicitly enabled.
    var token: String {
        get {
            UserDefaults.standard.string(forKey: Self.defaultTokenKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.defaultTokenKey)
        }
    }

    var archipelagoBaseURL: URL { serverManager.baseURL }
    var archipelagoToken: String { activeToken ?? serverManager.embeddedConfig.token }

    init(
        serverManager: ArchipelagoServerManager = ArchipelagoServerManager(),
        groupStore: ArchipelagoGroupChatStore = ArchipelagoGroupChatStore(),
        webServiceConfigReader: ArchipelagoWebServiceConfigReader = ArchipelagoWebServiceConfigReader()
    ) {
        self.serverManager = serverManager
        self.groupStore = groupStore
        self.webServiceConfigReader = webServiceConfigReader
        self.groupChats = groupStore.load()
    }

    func boot() {
        Task {
            NSLog("[Archipelago] boot: starting Archipelago via ServerManager...")
            isLoading = true
            isArchipelagoConnected = false
            connectionErrorMessage = nil

            let tokenCandidates = resolveArchipelagoTokenCandidates()
            guard !tokenCandidates.isEmpty else {
                NSLog("[Archipelago] boot: missing Archipelago web service token")
                connectionErrorMessage = "内嵌 Archipelago token 未生成。请重启 Archipelago 后重试。"
                isArchipelagoConnected = false
                isLoading = false
                return
            }
            // Use ServerManager to launch the embedded archipelago-server and wait for health.
            var connectedClient: ArchipelagoClient?
            var connectedAgents: [ArchipelagoAgentInfo] = []
            var connectedToken: String?
            for candidate in tokenCandidates {
                let started = await serverManager.start(token: candidate)
                guard started else { continue }

                let baseURL = archipelagoBaseURL
                let client = ArchipelagoClient(baseURL: baseURL, token: candidate)
                do {
                    connectedAgents = try await client.listAgents()
                    connectedClient = client
                    connectedToken = candidate
                    break
                } catch {
                    NSLog("[Archipelago] boot: Archipelago token candidate rejected or embedded server unreachable: \(error)")
                    serverManager.stop()
                }
            }

            guard let currentToken = connectedToken, let client = connectedClient else {
                let failureMessage = serverManager.lastFailure?.message ?? "内嵌 Archipelago 服务未能启动或通过健康检查。"
                NSLog("[Archipelago] boot: ServerManager failed to start/reach embedded Archipelago: %@", failureMessage)
                connectionErrorMessage = failureMessage
                isArchipelagoConnected = false
                isLoading = false
                return
            }
            activeToken = currentToken
            self.client = client

            availableAgents = connectedAgents
            isArchipelagoConnected = true
            NSLog("[Archipelago] boot: connected! \(connectedAgents.count) agents available")

            // Wire up WebSocket client
            let baseURL = archipelagoBaseURL
            let ws = ArchipelagoWSClient(baseURL: baseURL, token: currentToken)
            self.wsClient = ws
            setupWSEventHandlers(ws)
            ws.connect()
            NSLog("[Archipelago] boot: WebSocket client connected")

            await loadGroupsFromServer()
            isLoading = false
            await refreshGroupAgentRuntimeBindings()
            startGroupRuntimeSync()
            startGroupListSync()
        }
    }

    private func resolveArchipelagoTokenCandidates() -> [String] {
        var candidates: [String] = [serverManager.embeddedConfig.token]
        guard serverManager.allowsExternalFallback else { return candidates }

        let override = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if !override.isEmpty, !candidates.contains(override) {
            candidates.append(override)
        }
        if let saved = webServiceConfigReader.loadToken(), !candidates.contains(saved) {
            candidates.append(saved)
        }
        return candidates
    }

    func refreshAgents() async {
        guard let client else { return }
        do {
            availableAgents = try await client.listAgents()
        } catch {
            NSLog("[Archipelago] refreshAgents error: \(error)")
        }
    }

    func loadGroupsFromServer() async {
        guard let client else { return }
        do {
            let responses = try await reconciledServerGroups(try await client.listGroups(), client: client)
            applyServerGroups(responses)
            NSLog("[Archipelago] loaded \(responses.count) group chats from Archipelago")
        } catch {
            NSLog("[Archipelago] loadGroups error: \(error)")
        }
    }

    // MARK: - Group Chat CRUD

    func createGroupChat(
        name: String,
        folderPath: String,
        members: [ArchipelagoGroupMemberDraft],
        primaryAgentType: ArchipelagoAgentType
    ) {
        guard let client else {
            creationErrorMessage = connectionErrorMessage ?? "内嵌 Archipelago 服务未连接。"
            return
        }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedMembers = members.filter { $0.agentType.isAgentHubMVPType }
        guard !trimmedName.isEmpty, !selectedMembers.isEmpty else { return }

        isCreating = true
        creationErrorMessage = nil

        Task {
            do {
                let folder = try await client.openFolder(path: folderPath)
                let group = try await client.createGroup(
                    name: trimmedName,
                    folderId: folder.id,
                    folderPath: folder.path
                )
                var primaryGroupAgentId: Int?
                let workspaceName = URL(fileURLWithPath: folder.path).lastPathComponent

                for member in selectedMembers {
                    let role = Self.normalizedRole(member.role, fallback: member.agentType.defaultGroupRole)
                    let conversationId = try await resolveWorkspaceConversation(
                        client: client,
                        folderId: folder.id,
                        agentType: member.agentType,
                        workspaceName: workspaceName,
                        groupName: trimmedName
                    )
                    let groupAgent = try await client.addGroupAgent(
                        groupId: group.group.id,
                        agentType: member.agentType,
                        role: role,
                        conversationId: conversationId,
                        connectionId: nil,
                        workingDir: folder.path
                    )
                    if primaryGroupAgentId == nil {
                        primaryGroupAgentId = groupAgent.id
                    }
                    if member.agentType == primaryAgentType {
                        primaryGroupAgentId = groupAgent.id
                    }
                }

                if let primaryGroupAgentId {
                    _ = try await client.updateGroup(
                        id: group.group.id,
                        primaryAgentId: primaryGroupAgentId
                    )
                }
                await loadGroupsFromServer()
                selectedFolderURL = nil
                contentState = .chatList
                NSLog("[Archipelago] created group: \(trimmedName) (folderId: \(folder.id), agents: \(selectedMembers.count))")
            } catch {
                creationErrorMessage = "创建 Archipelago 会话失败: \(error.localizedDescription)"
                NSLog("[Archipelago] createGroupChat error: \(error)")
            }
            isCreating = false
        }
    }

    func addAgentToGroup(
        groupId: String,
        agentType: ArchipelagoAgentType,
        workingDir: String,
        role: String = ArchipelagoGroupAgentRole.coder.rawValue
    ) {
        guard let client,
              let groupDbId = Int(groupId),
              let group = group(byId: groupId) else { return }
        try? FileManager.default.createDirectory(atPath: workingDir, withIntermediateDirectories: true)
        let normalizedRole = Self.normalizedRole(role, fallback: agentType.defaultGroupRole)
        let folderId = group.folderId
        let workspaceName = group.folderPath
            .map { URL(fileURLWithPath: $0).lastPathComponent } ??
            URL(fileURLWithPath: workingDir).lastPathComponent
        let shouldSetPrimary = group.primaryAgentId == nil

        Task {
            do {
                let resolvedFolderId: Int
                if let folderId {
                    resolvedFolderId = folderId
                } else {
                    resolvedFolderId = try await client.openFolder(path: workingDir).id
                }
                let conversationId = try await resolveWorkspaceConversation(
                    client: client,
                    folderId: resolvedFolderId,
                    agentType: agentType,
                    workspaceName: workspaceName,
                    groupName: group.name
                )
                let groupAgent = try await client.addGroupAgent(
                    groupId: groupDbId,
                    agentType: agentType,
                    role: normalizedRole,
                    conversationId: conversationId,
                    connectionId: nil,
                    workingDir: workingDir
                )
                if shouldSetPrimary {
                    _ = try await client.updateGroup(id: groupDbId, primaryAgentId: groupAgent.id)
                }

                let connId = try await client.connect(agentType: agentType, workingDir: workingDir)
                _ = try await client.updateGroupAgent(
                    id: groupAgent.id,
                    connectionId: connId,
                    conversationId: conversationId
                )
                await loadGroupsFromServer()
                subscribeToAgent(connectionId: connId)
                NSLog("[Archipelago] agent \(agentType.rawValue) spawned via Archipelago desktop: \(connId)")

                for _ in 0..<30 {
                    try? await Task.sleep(for: .seconds(1))
                    let conns = try await client.listConnections()
                    if let conn = conns.first(where: { $0.id == connId }) {
                        updateAgentByConnection(connectionId: connId) { agent in
                            agent.status = conn.status
                        }
                        if conn.status == .connected {
                            NSLog("[Archipelago] agent \(agentType.rawValue) connected!")
                            break
                        }
                        if conn.status == .error || conn.status == .disconnected {
                            NSLog("[Archipelago] agent \(agentType.rawValue) failed: \(conn.status.rawValue)")
                            break
                        }
                    }
                }
            } catch {
                NSLog("[Archipelago] addAgent error: \(error)")
                await loadGroupsFromServer()
            }
        }
    }

    func isSendingGroupTask(groupId: String) -> Bool {
        sendingGroupTaskIds.contains(groupId)
    }

    func sendGroupTask(groupId: String, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let client else {
            setGroupError(groupId: groupId, message: ArchipelagoGroupTaskSendError.archipelagoDisconnected.localizedDescription)
            return
        }
        guard !sendingGroupTaskIds.contains(groupId) else { return }

        sendingGroupTaskIds.insert(groupId)
        setGroupError(groupId: groupId, message: nil)

        Task {
            var activeTarget: (connectionId: String, conversationId: Int, folderId: Int)?
            do {
                let target = try await ensurePrimaryAgentConnection(client: client, groupId: groupId)
                activeTarget = target
                updateAgent(conversationId: target.conversationId, connectionId: target.connectionId) { agent in
                    agent.status = .prompting
                    agent.isBlocked = false
                    agent.latestResponseSummary = "群聊任务已发送，主 Agent 正在拆解。"
                    agent.latestResponseAt = Date()
                }
                responseTextByConnection[target.connectionId] = ""
                try await client.prompt(
                    connectionId: target.connectionId,
                    text: trimmed,
                    folderId: target.folderId,
                    conversationId: target.conversationId,
                    collaborationMode: .auto
                )
                NSLog("[Archipelago] sent orchestrated group task to group \(groupId)")
            } catch {
                if let activeTarget {
                    updateAgent(
                        conversationId: activeTarget.conversationId,
                        connectionId: activeTarget.connectionId
                    ) { agent in
                        agent.status = .connected
                        agent.isBlocked = false
                    }
                    responseTextByConnection.removeValue(forKey: activeTarget.connectionId)
                }
                setGroupError(groupId: groupId, message: "发送群聊任务失败: \(error.localizedDescription)")
                NSLog("[Archipelago] sendGroupTask error: \(error)")
                await loadGroupsFromServer()
            }
            sendingGroupTaskIds.remove(groupId)
        }
    }

    func setPrimaryAgent(groupId: String, agentId: String) {
        guard let client,
              let groupDbId = Int(groupId),
              let agentDbId = Int(agentId),
              let groupIndex = groupChats.firstIndex(where: { $0.id == groupId }),
              groupChats[groupIndex].agents.contains(where: { $0.id == agentId }) else {
            return
        }
        let previousPrimaryAgentId = groupChats[groupIndex].primaryAgentId
        guard previousPrimaryAgentId != agentId else { return }

        groupChats[groupIndex].primaryAgentId = agentId
        groupChats[groupIndex].lastErrorMessage = nil
        persistGroupChats()

        Task {
            do {
                let response = try await client.updateGroup(
                    id: groupDbId,
                    primaryAgentId: agentDbId
                )
                applyServerGroup(response)
            } catch {
                if let index = groupChats.firstIndex(where: { $0.id == groupId }) {
                    groupChats[index].primaryAgentId = previousPrimaryAgentId
                    groupChats[index].lastErrorMessage = "设置主 Agent 失败: \(error.localizedDescription)"
                    persistGroupChats()
                }
                NSLog("[Archipelago] setPrimaryAgent error: \(error)")
                await loadGroupsFromServer()
            }
        }
    }

    func removeAgentFromGroup(groupId: String, agentId: String) {
        guard let idx = groupChats.firstIndex(where: { $0.id == groupId }),
              let aIdx = groupChats[idx].agents.firstIndex(where: { $0.id == agentId }) else { return }
        let agent = groupChats[idx].agents[aIdx]
        if let connId = agent.connectionId {
            unsubscribeFromAgent(connectionId: connId)
            Task { try? await client?.disconnect(connectionId: connId) }
        }
        groupChats[idx].agents.remove(at: aIdx)
        persistGroupChats()

        let agentDbId = Int(agentId)
        Task {
            do {
                if let conversationId = agent.conversationId {
                    try await client?.deleteConversation(conversationId: conversationId)
                } else if let agentDbId {
                    try await client?.removeGroupAgent(id: agentDbId, groupId: Int(groupId))
                }
                await loadGroupsFromServer()
            } catch {
                NSLog("[Archipelago] removeAgent error: \(error)")
                await loadGroupsFromServer()
            }
        }
    }

    func deleteGroupChat(groupId: String) {
        guard let idx = groupChats.firstIndex(where: { $0.id == groupId }) else { return }
        let group = groupChats[idx]
        for agent in groupChats[idx].agents {
            if let connId = agent.connectionId {
                unsubscribeFromAgent(connectionId: connId)
                Task { try? await client?.disconnect(connectionId: connId) }
            }
        }
        groupChats.remove(at: idx)
        persistGroupChats()

        guard let groupDbId = Int(groupId) else { return }
        Task {
            do {
                if let folderId = group.folderId {
                    try await client?.removeFolderFromWorkspace(folderId: folderId)
                } else {
                    try await client?.deleteGroup(id: groupDbId, folderId: nil)
                }
                await loadGroupsFromServer()
            } catch {
                NSLog("[Archipelago] deleteGroup error: \(error)")
                await loadGroupsFromServer()
            }
        }
    }

    func group(byId id: String) -> GroupChat? {
        groupChats.first { $0.id == id }
    }

    private func ensurePrimaryAgentConnection(
        client: ArchipelagoClient,
        groupId: String
    ) async throws -> (connectionId: String, conversationId: Int, folderId: Int) {
        guard let groupIndex = groupChats.firstIndex(where: { $0.id == groupId }) else {
            throw ArchipelagoGroupTaskSendError.missingGroup
        }
        let group = groupChats[groupIndex]
        guard let folderId = group.folderId else {
            throw ArchipelagoGroupTaskSendError.missingFolder
        }
        guard let primary = group.primaryAgent else {
            throw ArchipelagoGroupTaskSendError.missingPrimaryAgent
        }
        guard let conversationId = primary.conversationId else {
            throw ArchipelagoGroupTaskSendError.missingConversation
        }
        let liveConnections = (try? await client.listConnections()) ?? []
        if let connectionId = primary.connectionId {
            if let liveConnection = liveConnections.first(where: { $0.id == connectionId }) {
                updateAgent(conversationId: conversationId, connectionId: connectionId) { agent in
                    agent.status = liveConnection.status
                    agent.isBlocked = false
                }
                subscribeToAgent(connectionId: connectionId)
                switch liveConnection.status {
                case .connected:
                    return (connectionId, conversationId, folderId)
                case .connecting:
                    try await waitForAgentConnection(client: client, connectionId: connectionId)
                    return (connectionId, conversationId, folderId)
                case .prompting, .disconnected, .error:
                    throw ArchipelagoGroupTaskSendError.primaryConnectionNotReady(liveConnection.status)
                }
            } else {
                updateAgent(conversationId: conversationId, connectionId: connectionId) { agent in
                    agent.connectionId = nil
                    agent.status = .disconnected
                    agent.isBlocked = false
                }
            }
        }

        guard let primaryAgentDbId = Int(primary.id) else {
            throw ArchipelagoGroupTaskSendError.malformedAgentId
        }
        let sessionId = try? await client.conversationDetail(conversationId: conversationId).externalId
        let connectionId = try await client.connect(
            agentType: primary.agentType,
            workingDir: primary.workingDir,
            sessionId: sessionId
        )
        _ = try await client.updateGroupAgent(
            id: primaryAgentDbId,
            connectionId: connectionId,
            conversationId: conversationId
        )
        updateAgent(conversationId: conversationId, connectionId: nil) { agent in
            agent.connectionId = connectionId
            agent.status = .connecting
            agent.isBlocked = false
        }
        subscribeToAgent(connectionId: connectionId)
        try await waitForAgentConnection(client: client, connectionId: connectionId)
        return (connectionId, conversationId, folderId)
    }

    private func waitForAgentConnection(client: ArchipelagoClient, connectionId: String) async throws {
        for _ in 0..<30 {
            guard let conn = try await client.listConnections().first(where: { $0.id == connectionId }) else {
                try? await Task.sleep(for: .seconds(1))
                continue
            }
            updateAgentByConnection(connectionId: connectionId) { agent in
                agent.status = conn.status
            }
            if conn.status == .connected {
                return
            }
            if conn.status == .prompting || conn.status == .error || conn.status == .disconnected {
                throw ArchipelagoGroupTaskSendError.primaryConnectionNotReady(conn.status)
            }
            try? await Task.sleep(for: .seconds(1))
        }
        throw ArchipelagoGroupTaskSendError.primaryConnectionTimeout
    }

    // MARK: - Open in Archipelago App

    func archipelagoWorkspaceURL(for group: GroupChat) -> URL? {
        group.archipelagoWorkspaceURL(baseURL: archipelagoBaseURL)
    }

    func archipelagoWorkspaceURL(for group: GroupChat, agent: GroupChat.GroupAgent) -> URL? {
        group.archipelagoWorkspaceURL(baseURL: archipelagoBaseURL, agent: agent)
    }

    func openInArchipelago(group: GroupChat) {
        if let url = archipelagoWorkspaceURL(for: group) {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Navigation

    func navigateToCreate() {
        selectedFolderURL = nil
        contentState = .createChat
    }
    func navigateToAddAgents(groupId: String) {
        startGroupRuntimeSync(groupId: groupId)
        contentState = .addAgents(groupId: groupId)
    }
    func navigateToDetail(groupId: String) {
        contentState = .groupDetail(groupId: groupId)
        startGroupRuntimeSync(groupId: groupId)
    }
    func navigateBack() {
        startGroupRuntimeSync()
        contentState = .chatList
    }

    // MARK: - Runtime Status Synchronization

    func refreshGroupAgentRuntimeBindings(groupId: String? = nil) async {
        guard let client else { return }
        let targetGroupIds = Set(groupId.map { [$0] } ?? groupChats.map(\.id))
        let conversationIds = groupChats
            .filter { targetGroupIds.contains($0.id) }
            .flatMap(\.agents)
            .compactMap(\.conversationId)

        for conversationId in conversationIds {
            guard !Task.isCancelled else { return }
            do {
                guard let snapshot = try await client.sessionSnapshot(conversationId: conversationId) else {
                    handleMissingRuntimeSnapshot(conversationId: conversationId)
                    continue
                }
                applyRuntimeSnapshot(snapshot, fallbackConversationId: conversationId)
            } catch {
                NSLog("[Archipelago] runtime snapshot sync failed for conversation \(conversationId): \(error)")
            }
        }
    }

    func applyRuntimeSnapshot(_ snapshot: ArchipelagoLiveSessionSnapshot, fallbackConversationId: Int? = nil) {
        let conversationId = snapshot.conversationId ?? fallbackConversationId
        let snapshotIsDelegatedChild = isDelegatedChildConnection(snapshot.connectionId)
        if !snapshotIsDelegatedChild,
           let activeChildConnectionId = activeDelegatedChildConnectionId(forConversationId: conversationId) {
            subscribeToAgent(connectionId: activeChildConnectionId)
            return
        }
        if snapshotIsDelegatedChild {
            if let childConversationId = snapshot.conversationId {
                delegatedConversationIdByChildConnection[snapshot.connectionId] = childConversationId
            }
            let didUpdate = updateAgentByConnection(connectionId: snapshot.connectionId) { agent in
                switch snapshot.status {
                case .connected, .connecting:
                    agent.status = .prompting
                case .prompting, .disconnected, .error:
                    agent.status = snapshot.status
                }
                agent.isBlocked = snapshot.pendingPermission != nil
            }
            if didUpdate {
                subscribeToAgent(connectionId: snapshot.connectionId)
            }
            return
        }

        var shouldPersist = false
        var previousStatus: ArchipelagoConnectionStatus?
        var previousConnectionId: String?
        let didUpdate = updateAgent(conversationId: conversationId, connectionId: snapshot.connectionId) { agent in
            previousStatus = agent.status
            previousConnectionId = agent.connectionId
            agent.conversationId = conversationId ?? agent.conversationId
            shouldPersist = previousConnectionId != snapshot.connectionId
            agent.connectionId = snapshot.connectionId
            agent.status = snapshot.status
            agent.isBlocked = snapshot.pendingPermission != nil
            if let oldConnectionId = previousConnectionId, oldConnectionId != snapshot.connectionId {
                unsubscribeFromAgent(connectionId: oldConnectionId)
            }
        }

        if didUpdate {
            subscribeToAgent(connectionId: snapshot.connectionId)
            if shouldPersist {
                persistGroupChats()
            }
            if previousStatus == .prompting,
               snapshot.status != .prompting,
               snapshot.pendingPermission == nil {
                finishPolledTurn(conversationId: conversationId, connectionId: snapshot.connectionId)
            }
        }
    }

    private func startGroupRuntimeSync(groupId: String? = nil) {
        stopGroupRuntimeSync()
        groupRuntimeSyncTask = Task { [weak self] in
            await self?.refreshGroupAgentRuntimeBindings(groupId: groupId)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                await self?.refreshGroupAgentRuntimeBindings(groupId: groupId)
            }
        }
    }

    private func stopGroupRuntimeSync() {
        groupRuntimeSyncTask?.cancel()
        groupRuntimeSyncTask = nil
    }

    private func startGroupListSync() {
        stopGroupListSync()
        groupListSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                await self?.loadGroupsFromServer()
            }
        }
    }

    private func stopGroupListSync() {
        groupListSyncTask?.cancel()
        groupListSyncTask = nil
    }

    private func handleMissingRuntimeSnapshot(conversationId: Int) {
        if activeDelegatedChildConnectionId(forConversationId: conversationId) != nil {
            return
        }
        var previousStatus: ArchipelagoConnectionStatus?
        var connectionId: String?
        let didUpdate = updateAgent(conversationId: conversationId, connectionId: nil) { agent in
            previousStatus = agent.status
            connectionId = agent.connectionId
            agent.status = .connected
            agent.isBlocked = false
        }
        if didUpdate, previousStatus == .prompting {
            finishPolledTurn(conversationId: conversationId, connectionId: connectionId)
        }
    }

    // MARK: - WebSocket Event Handling

    private func setupWSEventHandlers(_ ws: ArchipelagoWSClient) {
        ws.onEvent = { [weak self] subscriptionId, eventType, rawJSON in
            Task { @MainActor [weak self] in
                self?.handleWSEvent(subscriptionId: subscriptionId, eventType: eventType, rawJSON: rawJSON)
            }
        }
        ws.onSnapshot = { [weak self] _, rawJSON in
            Task { @MainActor [weak self] in
                self?.handleWSSnapshot(rawJSON: rawJSON)
            }
        }
        ws.onDetached = { [weak self] subscriptionId, reason in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // Remove the subscription mapping when detached by server
                if let connId = self.subscriptions.first(where: { $0.value == subscriptionId })?.key {
                    self.subscriptions.removeValue(forKey: connId)
                    NSLog("[Archipelago] WS: subscription detached for connection \(connId): \(reason)")
                }
            }
        }
        ws.onGlobalEvent = { [weak self] channel, rawJSON in
            Task { @MainActor [weak self] in
                await self?.handleGlobalWSEvent(channel: channel, rawJSON: rawJSON)
            }
        }
    }

    private func handleGlobalWSEvent(channel: String, rawJSON: Data) async {
        switch channel {
        case "island://group-upserted":
            let decoder = JSONDecoder()
            guard let response = try? decoder.decode(ArchipelagoGroupChatResponse.self, from: rawJSON) else {
                await loadGroupsFromServer()
                return
            }
            applyServerGroup(response)
        case "island://group-deleted":
            let decoder = JSONDecoder()
            let payload = try? decoder.decode(ArchipelagoGroupDeletedPayload.self, from: rawJSON)
            removeServerDeletedGroup(groupId: payload?.groupId, folderId: payload?.folderId)
            await loadGroupsFromServer()
        case "island://agent-upserted", "island://agent-deleted":
            await loadGroupsFromServer()
        default:
            break
        }
    }

    private func handleWSEvent(subscriptionId: String, eventType: String, rawJSON: Data) {
        // Find the connectionId from subscriptionId
        guard let connectionId = subscriptions.first(where: { $0.value == subscriptionId })?.key else {
            NSLog("[Archipelago] WS: received event for unknown subscription \(subscriptionId)")
            return
        }

        switch eventType {
        case "status_changed":
            handleStatusChanged(connectionId: connectionId, rawJSON: rawJSON)
        case "content_delta":
            handleContentDelta(connectionId: connectionId, rawJSON: rawJSON)
        case "tool_call":
            handleToolCall(connectionId: connectionId, rawJSON: rawJSON)
        case "tool_call_update":
            handleToolCallUpdate(connectionId: connectionId, rawJSON: rawJSON)
        case "permission_request":
            handlePermissionRequest(connectionId: connectionId)
        case "group_collaboration_plan":
            handleGroupCollaborationPlan(connectionId: connectionId, rawJSON: rawJSON)
        case "delegation_started":
            handleDelegationStarted(connectionId: connectionId, rawJSON: rawJSON)
        case "turn_complete":
            handleTurnComplete(connectionId: connectionId)
        default:
            break
        }
    }

    private func handleStatusChanged(connectionId: String, rawJSON: Data) {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ArchipelagoStatusChangedPayload.self, from: rawJSON) else {
            NSLog("[Archipelago] WS: failed to decode status_changed payload")
            return
        }
        let status = projectedStatusForDelegatedChild(connectionId: connectionId, status: payload.status)
        updateAgentByConnection(connectionId: connectionId) { agent in
            agent.status = status
            // Clear blocked flag when status changes to something active
            if status == .prompting || status == .connected {
                agent.isBlocked = false
            }
        }
        if payload.status == .prompting {
            responseTextByConnection[connectionId] = ""
        }
        NSLog("[Archipelago] WS: status_changed → \(payload.status.rawValue) for connection \(connectionId)")
    }

    private func handleContentDelta(connectionId: String, rawJSON: Data) {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ArchipelagoContentDelta.self, from: rawJSON) else {
            NSLog("[Archipelago] WS: failed to decode content_delta payload")
            return
        }
        responseTextByConnection[connectionId, default: ""].append(payload.text)
    }

    private func handleToolCall(connectionId: String, rawJSON: Data) {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ArchipelagoToolCall.self, from: rawJSON) else {
            NSLog("[Archipelago] WS: failed to decode tool_call payload")
            return
        }
        rememberDelegationToolCall(payload, primaryConnectionId: connectionId)
        if let delegation = payload.meta?.delegation {
            handleDelegationMeta(
                primaryConnectionId: connectionId,
                toolCallId: payload.toolCallId,
                delegation: delegation,
                rawOutput: payload.rawOutput
            )
        }
        handleDelegationToolCallTerminalIfNeeded(payload)
    }

    private func handleToolCallUpdate(connectionId: String, rawJSON: Data) {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ArchipelagoToolCall.self, from: rawJSON) else {
            NSLog("[Archipelago] WS: failed to decode tool_call_update payload")
            return
        }
        rememberDelegationToolCall(payload, primaryConnectionId: connectionId)
        if let delegation = payload.meta?.delegation {
            handleDelegationMeta(
                primaryConnectionId: connectionId,
                toolCallId: payload.toolCallId,
                delegation: delegation,
                rawOutput: payload.rawOutput
            )
        }
        handleDelegationToolCallTerminalIfNeeded(payload)
    }

    private func handleWSSnapshot(rawJSON: Data) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let frame = try? decoder.decode(ArchipelagoSnapshotFrame.self, from: rawJSON) else {
            NSLog("[Archipelago] WS: failed to decode snapshot frame")
            return
        }
        applyRuntimeSnapshot(frame.snapshot, fallbackConversationId: frame.snapshot.conversationId)
        NSLog("[Archipelago] WS: snapshot → \(frame.snapshot.status.rawValue) for connection \(frame.connectionId)")
    }

    private func handlePermissionRequest(connectionId: String) {
        updateAgentByConnection(connectionId: connectionId) { agent in
            agent.isBlocked = true
        }
        NSLog("[Archipelago] WS: permission_request → blocked for connection \(connectionId)")
    }

    private func handleGroupCollaborationPlan(connectionId: String, rawJSON: Data) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let payload = try? decoder.decode(ArchipelagoGroupCollaborationPlanPayload.self, from: rawJSON) else {
            NSLog("[Archipelago] WS: failed to decode group_collaboration_plan payload")
            return
        }
        let groupId = String(payload.groupId)
        let memberIds = Set(payload.members.map { String($0.agentId) })
        guard groupChats.contains(where: { $0.id == groupId }) else {
            return
        }
        if memberIds.isEmpty {
            collaborationMemberIdsByPrimaryConnection.removeValue(forKey: connectionId)
        } else {
            collaborationMemberIdsByPrimaryConnection[connectionId] = memberIds
        }
        notifyGroupChatsChanged()
        NSLog("[Archipelago] WS: group_collaboration_plan → \(payload.members.count) members for group \(groupId)")
    }

    private func handleDelegationStarted(connectionId: String, rawJSON: Data) {
        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ArchipelagoDelegationStarted.self, from: rawJSON),
              let childConnectionId = payload.childConnectionId?.nilIfBlank else {
            NSLog("[Archipelago] WS: failed to decode delegation_started payload")
            return
        }
        bindDelegatedChildAgent(
            primaryConnectionId: payload.parentConnectionId?.nilIfBlank
                ?? childConnectionToPrimaryConnection[childConnectionId]
                ?? connectionId,
            childAgentType: payload.childAgentType,
            childConnectionId: childConnectionId,
            childConversationId: payload.childConversationId,
            task: payload.task
        )
        NSLog("[Archipelago] WS: delegation_started → \(payload.childAgentType.rawValue) child \(childConnectionId)")
    }

    private func rememberDelegationToolCall(_ payload: ArchipelagoToolCall, primaryConnectionId: String) {
        guard Self.isDelegationToolCall(payload) else {
            return
        }
        delegationPrimaryConnectionByToolCallId[payload.toolCallId] = primaryConnectionId
        guard let arguments = Self.delegationArguments(from: payload.rawInput) else {
            return
        }
        if let agentType = arguments.agentType, agentType != .unknown {
            delegationAgentTypeByToolCallId[payload.toolCallId] = agentType
        }
        if let task = arguments.task?.nilIfBlank {
            delegationTaskByToolCallId[payload.toolCallId] = task
        }
    }

    private func handleDelegationMeta(
        primaryConnectionId: String,
        toolCallId: String,
        delegation: ArchipelagoDelegationMeta,
        rawOutput: String?
    ) {
        guard let childConnectionId = delegation.childConnectionId?.nilIfBlank else {
            return
        }
        delegationChildConnectionByToolCallId[toolCallId] = childConnectionId
        let parentConnectionId = delegationPrimaryConnectionByToolCallId[toolCallId] ?? primaryConnectionId
        if let childConversationId = delegation.childConversationId {
            delegatedConversationIdByChildConnection[childConnectionId] = childConversationId
        }
        let status = delegation.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if status == "pending" || status == "running" {
            guard let agentType = delegationAgentTypeByToolCallId[toolCallId],
                  agentType != .unknown else {
                if isDelegatedChildConnection(childConnectionId) {
                    updateAgentByConnection(connectionId: childConnectionId) { agent in
                        agent.status = .prompting
                        agent.isBlocked = false
                    }
                }
                return
            }
            bindDelegatedChildAgent(
                primaryConnectionId: parentConnectionId,
                childAgentType: agentType,
                childConnectionId: childConnectionId,
                childConversationId: delegation.childConversationId,
                task: delegationTaskByToolCallId[toolCallId]
            )
        } else if status == "completed" || status == "ok" {
            finishDelegatedChildTurnIfReady(
                conversationId: delegation.childConversationId,
                connectionId: childConnectionId,
                explicitSummary: Self.delegationOutcomeSummary(from: rawOutput)
            )
        } else if status == "failed" || status == "err" || status == "cancelled" || status == "error" {
            finishDelegatedChildTurnIfReady(
                conversationId: delegation.childConversationId,
                connectionId: childConnectionId,
                explicitSummary: Self.delegationOutcomeSummary(from: rawOutput) ?? "Agent 任务失败。"
            )
        }
    }

    private func handleDelegationToolCallTerminalIfNeeded(_ payload: ArchipelagoToolCall) {
        let status = payload.status?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard status == "completed" || status == "failed" || status == "cancelled" || status == "error",
              let childConnectionId = delegationChildConnectionByToolCallId[payload.toolCallId],
              isDelegatedChildConnection(childConnectionId) else {
            return
        }
        let explicitSummary = Self.delegationOutcomeSummary(from: payload.rawOutput)
        finishDelegatedChildTurnIfReady(
            conversationId: delegatedConversationIdByChildConnection[childConnectionId],
            connectionId: childConnectionId,
            explicitSummary: explicitSummary
        )
    }

    private func bindDelegatedChildAgent(
        primaryConnectionId: String,
        childAgentType: ArchipelagoAgentType,
        childConnectionId: String,
        childConversationId: Int?,
        task: String?
    ) {
        guard childAgentType != .unknown,
              let primaryContext = agentContext(connectionId: primaryConnectionId) else {
            return
        }
        let groupIndex = primaryContext.groupIndex
        guard groupChats.indices.contains(groupIndex),
              let agentIndex = delegatedAgentIndex(
                  groupIndex: groupIndex,
                  primaryAgentIndex: primaryContext.agentIndex,
                  primaryConnectionId: primaryConnectionId,
                  childAgentType: childAgentType,
                  childConnectionId: childConnectionId
              ) else {
            return
        }

        childConnectionToPrimaryConnection[childConnectionId] = primaryConnectionId
        if let childConversationId {
            delegatedConversationIdByChildConnection[childConnectionId] = childConversationId
        }

        let previousConnectionId = groupChats[groupIndex].agents[agentIndex].connectionId
        if previousConnectionId != childConnectionId {
            if let previousConnectionId {
                previousConnectionIdByChildConnection[childConnectionId] = previousConnectionId
                unsubscribeFromAgent(connectionId: previousConnectionId)
            } else {
                previousConnectionIdByChildConnection.removeValue(forKey: childConnectionId)
            }
        }

        groupChats[groupIndex].agents[agentIndex].connectionId = childConnectionId
        groupChats[groupIndex].agents[agentIndex].status = .prompting
        groupChats[groupIndex].agents[agentIndex].isBlocked = false
        if responseTextByConnection[childConnectionId] == nil {
            responseTextByConnection[childConnectionId] = ""
        }
        subscribeToAgent(connectionId: childConnectionId)
        persistGroupChats()

        if let taskSummary = Self.responseSummary(from: task) {
            NSLog("[Archipelago] delegation bound \(childAgentType.rawValue) child \(childConnectionId): \(taskSummary)")
        } else {
            NSLog("[Archipelago] delegation bound \(childAgentType.rawValue) child \(childConnectionId)")
        }
    }

    private func delegatedAgentIndex(
        groupIndex: Int,
        primaryAgentIndex: Int,
        primaryConnectionId: String,
        childAgentType: ArchipelagoAgentType,
        childConnectionId: String
    ) -> Int? {
        if let existingIndex = groupChats[groupIndex].agents.firstIndex(where: { $0.connectionId == childConnectionId }) {
            return existingIndex
        }
        let plannedMemberIds = collaborationMemberIdsByPrimaryConnection[primaryConnectionId] ?? []
        if let plannedIndex = groupChats[groupIndex].agents.indices.first(where: { index in
            index != primaryAgentIndex &&
                plannedMemberIds.contains(groupChats[groupIndex].agents[index].id) &&
                groupChats[groupIndex].agents[index].agentType == childAgentType
        }) {
            return plannedIndex
        }
        return groupChats[groupIndex].agents.indices.first { index in
            index != primaryAgentIndex &&
                groupChats[groupIndex].agents[index].agentType == childAgentType
        }
    }

    private func handleTurnComplete(connectionId: String) {
        if isDelegatedChildConnection(connectionId) {
            finishDelegatedChildTurnIfReady(
                conversationId: delegatedConversationIdByChildConnection[connectionId],
                connectionId: connectionId,
                explicitSummary: nil
            )
            if isDelegatedChildConnection(connectionId) {
                updateAgentByConnection(connectionId: connectionId) { agent in
                    agent.status = .prompting
                    agent.isBlocked = false
                }
            }
            NSLog("[Archipelago] WS: delegated turn_complete observed for child connection \(connectionId)")
            return
        }

        updateAgentByConnection(connectionId: connectionId) { agent in
            agent.status = .connected
            agent.isBlocked = false
        }
        let bufferedSummary = Self.responseSummary(from: responseTextByConnection.removeValue(forKey: connectionId))
        if let bufferedSummary {
            recordTurnCompletion(connectionId: connectionId, summary: bufferedSummary)
        } else {
            Task { [weak self] in
                guard let self else { return }
                let fallbackSummary = await self.fetchLatestAssistantSummary(connectionId: connectionId)
                    ?? "Agent 已完成回复。"
                self.recordTurnCompletion(connectionId: connectionId, summary: fallbackSummary)
            }
        }
        NSLog("[Archipelago] WS: turn_complete → idle for connection \(connectionId)")
    }

    private func fetchLatestAssistantSummary(connectionId: String) async -> String? {
        if let conversationId = delegatedConversationIdByChildConnection[connectionId] {
            return await fetchLatestAssistantSummary(conversationId: conversationId)
        }
        guard let conversationId = agentContext(connectionId: connectionId)?.conversationId else {
            return nil
        }
        return await fetchLatestAssistantSummary(conversationId: conversationId)
    }

    private func fetchLatestAssistantSummary(conversationId: Int) async -> String? {
        guard let client else { return nil }
        do {
            let detail = try await client.conversationDetail(conversationId: conversationId)
            return Self.responseSummary(from: detail.latestAssistantSummary)
        } catch {
            NSLog("[Archipelago] failed to fetch conversation detail for summary: \(error)")
            return nil
        }
    }

    private func finishPolledTurn(conversationId: Int?, connectionId: String?) {
        guard conversationId != nil || connectionId != nil else { return }
        if isDelegatedChildConnection(connectionId) {
            return
        }
        if activeDelegatedChildConnectionId(forConversationId: conversationId) != nil {
            return
        }
        Task { [weak self] in
            guard let self else { return }
            let summary: String?
            if let buffered = connectionId.flatMap({ Self.responseSummary(from: self.responseTextByConnection.removeValue(forKey: $0)) }) {
                summary = buffered
            } else if let conversationId {
                summary = await self.fetchLatestAssistantSummary(conversationId: conversationId)
            } else if let connectionId {
                summary = await self.fetchLatestAssistantSummary(connectionId: connectionId)
            } else {
                summary = nil
            }
            self.recordTurnCompletion(
                conversationId: conversationId,
                connectionId: connectionId,
                summary: summary ?? "Agent 已完成回复。"
            )
        }
    }

    private func finishDelegatedChildTurnIfReady(
        conversationId: Int?,
        connectionId: String,
        explicitSummary: String?
    ) {
        guard isDelegatedChildConnection(connectionId) else { return }
        Task { [weak self] in
            guard let self else { return }
            let summary: String?
            if let explicitSummary {
                summary = explicitSummary
            } else if let buffered = Self.responseSummary(from: self.responseTextByConnection.removeValue(forKey: connectionId)) {
                summary = buffered
            } else if let conversationId {
                summary = await self.fetchLatestAssistantSummary(conversationId: conversationId)
            } else {
                summary = await self.fetchLatestAssistantSummary(connectionId: connectionId)
            }
            guard let summary else {
                return
            }
            self.recordTurnCompletion(conversationId: conversationId, connectionId: connectionId, summary: summary)
        }
    }

    private func recordTurnCompletion(connectionId: String, summary: String) {
        recordTurnCompletion(conversationId: nil, connectionId: connectionId, summary: summary)
    }

    private func recordTurnCompletion(conversationId: Int?, connectionId: String?, summary: String) {
        guard let context = agentContext(conversationId: conversationId, connectionId: connectionId) else { return }
        let completingConnectionId = connectionId ?? groupChats[context.groupIndex].agents[context.agentIndex].connectionId
        groupChats[context.groupIndex].agents[context.agentIndex].status = .connected
        groupChats[context.groupIndex].agents[context.agentIndex].isBlocked = false
        groupChats[context.groupIndex].agents[context.agentIndex].latestResponseSummary = summary
        groupChats[context.groupIndex].agents[context.agentIndex].latestResponseAt = Date()
        let primaryConnectionId = completingConnectionId.flatMap { childConnectionToPrimaryConnection[$0] }
        if let childConnectionId = completingConnectionId, let primaryConnectionId {
            restoreDelegatedChildAgentConnection(
                childConnectionId: childConnectionId,
                primaryConnectionId: primaryConnectionId,
                context: context
            )
        } else {
            completeCollaborationMembers(
                primaryConnectionId: completingConnectionId,
                groupIndex: context.groupIndex
            )
        }
        persistGroupChats()

        let group = groupChats[context.groupIndex]
        let agent = group.agents[context.agentIndex]
        onAgentTurnCompleted?(
            ArchipelagoAgentTurnCompletion(
                groupId: group.id,
                groupName: group.name,
                agentId: agent.id,
                agentType: agent.agentType,
                role: agent.role,
                summary: summary
            )
        )
    }

    private func completeCollaborationMembers(
        primaryConnectionId: String?,
        groupIndex: Int
    ) {
        guard let primaryConnectionId,
              let memberIds = collaborationMemberIdsByPrimaryConnection.removeValue(forKey: primaryConnectionId),
              groupChats.indices.contains(groupIndex) else {
            return
        }
        var activeMemberIds: Set<String> = []
        for agentIndex in groupChats[groupIndex].agents.indices {
            guard memberIds.contains(groupChats[groupIndex].agents[agentIndex].id) else { continue }
            if let connectionId = groupChats[groupIndex].agents[agentIndex].connectionId,
               childConnectionToPrimaryConnection[connectionId] == primaryConnectionId {
                activeMemberIds.insert(groupChats[groupIndex].agents[agentIndex].id)
            } else if groupChats[groupIndex].agents[agentIndex].status == .prompting {
                groupChats[groupIndex].agents[agentIndex].status = .connected
                groupChats[groupIndex].agents[agentIndex].isBlocked = false
            }
        }
        if !activeMemberIds.isEmpty {
            collaborationMemberIdsByPrimaryConnection[primaryConnectionId] = activeMemberIds
        }
    }

    private func restoreDelegatedChildAgentConnection(
        childConnectionId: String,
        primaryConnectionId: String,
        context: (groupIndex: Int, agentIndex: Int, conversationId: Int?)
    ) {
        childConnectionToPrimaryConnection.removeValue(forKey: childConnectionId)
        delegatedConversationIdByChildConnection.removeValue(forKey: childConnectionId)
        if var memberIds = collaborationMemberIdsByPrimaryConnection[primaryConnectionId] {
            memberIds.remove(groupChats[context.groupIndex].agents[context.agentIndex].id)
            if memberIds.isEmpty {
                collaborationMemberIdsByPrimaryConnection.removeValue(forKey: primaryConnectionId)
            } else {
                collaborationMemberIdsByPrimaryConnection[primaryConnectionId] = memberIds
            }
        }
        unsubscribeFromAgent(connectionId: childConnectionId)
        if let previousConnectionId = previousConnectionIdByChildConnection.removeValue(forKey: childConnectionId) {
            groupChats[context.groupIndex].agents[context.agentIndex].connectionId = previousConnectionId
            subscribeToAgent(connectionId: previousConnectionId)
        } else if groupChats[context.groupIndex].agents[context.agentIndex].connectionId == childConnectionId {
            groupChats[context.groupIndex].agents[context.agentIndex].connectionId = nil
        }
    }

    private func activeDelegatedChildConnectionId(forConversationId conversationId: Int?) -> String? {
        guard let conversationId,
              let context = agentContext(conversationId: conversationId, connectionId: nil),
              let connectionId = groupChats[context.groupIndex].agents[context.agentIndex].connectionId,
              isDelegatedChildConnection(connectionId) else {
            return nil
        }
        return connectionId
    }

    private func isDelegatedChildConnection(_ connectionId: String?) -> Bool {
        guard let connectionId else { return false }
        return childConnectionToPrimaryConnection[connectionId] != nil
    }

    private func projectedStatusForDelegatedChild(
        connectionId: String,
        status: ArchipelagoConnectionStatus
    ) -> ArchipelagoConnectionStatus {
        guard isDelegatedChildConnection(connectionId) else {
            return status
        }
        switch status {
        case .connected, .connecting:
            return .prompting
        case .prompting, .disconnected, .error:
            return status
        }
    }

    private func agentContext(connectionId: String) -> (groupIndex: Int, agentIndex: Int, conversationId: Int?)? {
        agentContext(conversationId: nil, connectionId: connectionId)
    }

    private func agentContext(
        conversationId: Int?,
        connectionId: String?
    ) -> (groupIndex: Int, agentIndex: Int, conversationId: Int?)? {
        for gIdx in groupChats.indices {
            if let aIdx = groupChats[gIdx].agents.firstIndex(where: { agent in
                if let connectionId, agent.connectionId == connectionId {
                    return true
                }
                if let conversationId, agent.conversationId == conversationId {
                    return true
                }
                return false
            }) {
                return (gIdx, aIdx, groupChats[gIdx].agents[aIdx].conversationId)
            }
        }
        return nil
    }

    @discardableResult
    private func updateAgentByConnection(connectionId: String, update: (inout GroupChat.GroupAgent) -> Void) -> Bool {
        for gIdx in groupChats.indices {
            if let aIdx = groupChats[gIdx].agents.firstIndex(where: { $0.connectionId == connectionId }) {
                update(&groupChats[gIdx].agents[aIdx])
                notifyGroupChatsChanged()
                return true
            }
        }
        return false
    }

    @discardableResult
    private func updateAgent(
        conversationId: Int?,
        connectionId: String?,
        update: (inout GroupChat.GroupAgent) -> Void
    ) -> Bool {
        for gIdx in groupChats.indices {
            if let aIdx = groupChats[gIdx].agents.firstIndex(where: { agent in
                if let conversationId, agent.conversationId == conversationId {
                    return true
                }
                if let connectionId, agent.connectionId == connectionId {
                    return true
                }
                return false
            }) {
                update(&groupChats[gIdx].agents[aIdx])
                notifyGroupChatsChanged()
                return true
            }
        }
        return false
    }

    // MARK: - Server Group Projection

    private func applyServerGroups(_ responses: [ArchipelagoGroupChatResponse]) {
        let previousGroups = groupChats
        let previousConnectionIds = Set(previousGroups.flatMap(\.agents).compactMap(\.connectionId))
        groupChats = responses.map { response in
            mapServerGroup(response, previousGroups: previousGroups)
        }
        let currentConnectionIds = Set(groupChats.flatMap(\.agents).compactMap(\.connectionId))
        for connectionId in previousConnectionIds.subtracting(currentConnectionIds) {
            unsubscribeFromAgent(connectionId: connectionId)
        }
        leaveMissingGroupScreenIfNeeded()
        persistGroupChats()
        resubscribeKnownAgentConnections()
    }

    private func applyServerGroup(_ response: ArchipelagoGroupChatResponse) {
        let previousGroups = groupChats
        let group = mapServerGroup(response, previousGroups: previousGroups)
        if let index = groupChats.firstIndex(where: { $0.id == group.id }) {
            groupChats[index] = group
        } else {
            groupChats.insert(group, at: 0)
        }
        persistGroupChats()
        resubscribeKnownAgentConnections()
    }

    private func removeServerDeletedGroup(groupId: Int?, folderId: Int?) {
        let oldConnectionIds = Set(groupChats.flatMap(\.agents).compactMap(\.connectionId))
        groupChats.removeAll { group in
            if let groupId, group.id == String(groupId) {
                return true
            }
            if let folderId, group.folderId == folderId {
                return true
            }
            return false
        }
        let newConnectionIds = Set(groupChats.flatMap(\.agents).compactMap(\.connectionId))
        for connectionId in oldConnectionIds.subtracting(newConnectionIds) {
            unsubscribeFromAgent(connectionId: connectionId)
        }
        leaveMissingGroupScreenIfNeeded()
        persistGroupChats()
    }

    private func setGroupError(groupId: String, message: String?) {
        guard let index = groupChats.firstIndex(where: { $0.id == groupId }) else { return }
        groupChats[index].lastErrorMessage = message
        persistGroupChats()
    }

    private func leaveMissingGroupScreenIfNeeded() {
        if case let .groupDetail(currentGroupId) = contentState,
           !groupChats.contains(where: { $0.id == currentGroupId }) {
            contentState = .chatList
        }
        if case let .addAgents(currentGroupId) = contentState,
           !groupChats.contains(where: { $0.id == currentGroupId }) {
            contentState = .chatList
        }
    }

    private func mapServerGroup(
        _ response: ArchipelagoGroupChatResponse,
        previousGroups: [GroupChat]
    ) -> GroupChat {
        let groupId = String(response.group.id)
        let previousGroup = previousGroups.first { $0.id == groupId }
        let agents = response.agents.map { agent in
            mapServerAgent(agent, previousGroup: previousGroup)
        }
        let primaryAgentId = response.group.primaryAgentId.map(String.init)
            ?? previousGroup?.primaryAgentId
            ?? agents.first?.id
        return GroupChat(
            id: groupId,
            name: response.group.name,
            primaryAgentId: primaryAgentId,
            agents: agents,
            createdAt: Self.parseServerDate(response.group.createdAt) ?? previousGroup?.createdAt ?? Date(),
            folderId: response.group.folderId,
            folderPath: response.group.folderPath,
            lastErrorMessage: previousGroup?.lastErrorMessage
        )
    }

    private func mapServerAgent(
        _ agent: ArchipelagoGroupChatResponse.GroupAgentInfo,
        previousGroup: GroupChat?
    ) -> GroupChat.GroupAgent {
        let agentId = String(agent.id)
        let previousAgent = previousGroup?.agents.first { existing in
            if existing.id == agentId {
                return true
            }
            if let conversationId = agent.conversationId,
               existing.conversationId == conversationId {
                return true
            }
            return false
        }
        let hasActiveDelegatedChild = isDelegatedChildConnection(previousAgent?.connectionId)
        return GroupChat.GroupAgent(
            id: agentId,
            agentType: agent.agentType,
            role: agent.role,
            conversationId: agent.conversationId,
            connectionId: hasActiveDelegatedChild ? previousAgent?.connectionId : (agent.connectionId ?? previousAgent?.connectionId),
            status: hasActiveDelegatedChild ? (previousAgent?.status ?? .prompting) : (previousAgent?.status ?? .connected),
            isBlocked: previousAgent?.isBlocked ?? false,
            workingDir: agent.workingDir,
            latestResponseSummary: previousAgent?.latestResponseSummary,
            latestResponseAt: previousAgent?.latestResponseAt
        )
    }

    private func reconciledServerGroups(
        _ responses: [ArchipelagoGroupChatResponse],
        client: ArchipelagoClient
    ) async throws -> [ArchipelagoGroupChatResponse] {
        guard !isReconcilingGroupConversationBindings else { return responses }
        isReconcilingGroupConversationBindings = true
        defer { isReconcilingGroupConversationBindings = false }

        var output = responses
        for responseIndex in output.indices {
            let response = output[responseIndex]
            guard let folderId = response.group.folderId else { continue }
            let workspaceName = Self.workspaceName(
                folderPath: response.group.folderPath,
                fallback: response.group.name
            )
            var agents = response.agents

            for agentIndex in agents.indices {
                let agent = agents[agentIndex]
                if agent.conversationId != nil {
                    continue
                }
                let conversationId = try await resolveWorkspaceConversation(
                    client: client,
                    folderId: folderId,
                    agentType: agent.agentType,
                    workspaceName: workspaceName,
                    groupName: response.group.name
                )
                guard agent.conversationId != conversationId else { continue }
                let updatedAgent = try await client.updateGroupAgent(
                    id: agent.id,
                    conversationId: conversationId
                )
                agents[agentIndex] = updatedAgent
            }

            output[responseIndex] = ArchipelagoGroupChatResponse(
                group: response.group,
                agents: agents
            )
        }

        return output
    }

    private func resubscribeKnownAgentConnections() {
        let knownConnectionIds = Set(groupChats.flatMap(\.agents).compactMap(\.connectionId))
        for connectionId in Array(subscriptions.keys) where !knownConnectionIds.contains(connectionId) {
            unsubscribeFromAgent(connectionId: connectionId)
        }
        for connectionId in knownConnectionIds {
            subscribeToAgent(connectionId: connectionId)
        }
    }

    // MARK: - WebSocket Subscription Management

    func subscribeToAgent(connectionId: String) {
        guard let wsClient, subscriptions[connectionId] == nil else { return }
        let subscriptionId = "sub-\(connectionId)"
        subscriptions[connectionId] = subscriptionId
        wsClient.attach(subscriptionId: subscriptionId, connectionId: connectionId)
        NSLog("[Archipelago] WS: attached subscription \(subscriptionId) for connection \(connectionId)")
    }

    func unsubscribeFromAgent(connectionId: String) {
        guard let wsClient, let subscriptionId = subscriptions[connectionId] else { return }
        wsClient.detach(subscriptionId: subscriptionId)
        subscriptions.removeValue(forKey: connectionId)
        responseTextByConnection.removeValue(forKey: connectionId)
        NSLog("[Archipelago] WS: detached subscription \(subscriptionId) for connection \(connectionId)")
    }

    // MARK: - Lifecycle

    func shutdown() {
        stopGroupRuntimeSync()
        stopGroupListSync()
        // Detach all active subscriptions before disconnecting
        for (_, subscriptionId) in subscriptions {
            wsClient?.detach(subscriptionId: subscriptionId)
        }
        subscriptions.removeAll()
        responseTextByConnection.removeAll()
        collaborationMemberIdsByPrimaryConnection.removeAll()
        childConnectionToPrimaryConnection.removeAll()
        delegatedConversationIdByChildConnection.removeAll()
        previousConnectionIdByChildConnection.removeAll()
        delegationPrimaryConnectionByToolCallId.removeAll()
        delegationAgentTypeByToolCallId.removeAll()
        delegationTaskByToolCallId.removeAll()
        delegationChildConnectionByToolCallId.removeAll()
        wsClient?.disconnect()
        wsClient = nil
        client = nil
        activeToken = nil
        isArchipelagoConnected = false
        isLoading = false
        serverManager.stop()
    }

    private static func normalizedRole(_ role: String, fallback: String) -> String {
        let trimmed = role.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }

    private func resolveWorkspaceConversation(
        client: ArchipelagoClient,
        folderId: Int,
        agentType: ArchipelagoAgentType,
        workspaceName: String,
        groupName: String
    ) async throws -> Int {
        let title = Self.workspaceConversationTitle(workspaceName: workspaceName, agentType: agentType)
        let conversations = try await client.listAllConversations(folderIds: [folderId])
        if let existing = conversations.first(where: { conversation in
            conversation.folderId == folderId &&
                conversation.agentType == agentType &&
                conversation.title == title
        }) {
            try await reconcileLegacyGroupConversationTitles(
                client: client,
                conversations: conversations,
                folderId: folderId,
                agentType: agentType,
                desiredTitle: title,
                groupName: groupName,
                protectedConversationId: existing.id
            )
            return existing.id
        }

        let legacyTitle = Self.groupConversationTitle(groupName: groupName, agentType: agentType)
        if legacyTitle != title,
           let legacy = conversations.first(where: { conversation in
               conversation.folderId == folderId &&
                   conversation.agentType == agentType &&
                   conversation.title == legacyTitle
           }) {
            try await client.updateConversationTitle(conversationId: legacy.id, title: title)
            try await reconcileLegacyGroupConversationTitles(
                client: client,
                conversations: conversations,
                folderId: folderId,
                agentType: agentType,
                desiredTitle: title,
                groupName: groupName,
                protectedConversationId: legacy.id
            )
            return legacy.id
        }

        return try await client.createConversation(
            folderId: folderId,
            agentType: agentType,
            title: title
        )
    }

    private func reconcileLegacyGroupConversationTitles(
        client: ArchipelagoClient,
        conversations: [ArchipelagoDBConversationSummary],
        folderId: Int,
        agentType: ArchipelagoAgentType,
        desiredTitle: String,
        groupName: String,
        protectedConversationId: Int
    ) async throws {
        let legacyTitle = Self.groupConversationTitle(groupName: groupName, agentType: agentType)
        guard legacyTitle != desiredTitle else { return }

        let legacyConversations = conversations.filter { conversation in
            conversation.folderId == folderId &&
                conversation.agentType == agentType &&
                conversation.title == legacyTitle &&
                conversation.id != protectedConversationId
        }

        for conversation in legacyConversations {
            if conversation.messageCount == 0 {
                try await client.deleteConversation(conversationId: conversation.id)
            } else {
                let preservedTitle = Self.preservedLegacyConversationTitle(
                    desiredTitle: desiredTitle,
                    groupName: groupName,
                    conversationId: conversation.id
                )
                try await client.updateConversationTitle(
                    conversationId: conversation.id,
                    title: preservedTitle
                )
            }
        }
    }

    private static func workspaceConversationTitle(
        workspaceName: String,
        agentType: ArchipelagoAgentType
    ) -> String {
        "\(workspaceName) · \(agentType.displayName)"
    }

    private static func groupConversationTitle(
        groupName: String,
        agentType: ArchipelagoAgentType
    ) -> String {
        "\(groupName) · \(agentType.displayName)"
    }

    private static func preservedLegacyConversationTitle(
        desiredTitle: String,
        groupName: String,
        conversationId: Int
    ) -> String {
        let trimmedGroupName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupName.isEmpty else {
            return "\(desiredTitle) · legacy \(conversationId)"
        }
        return "\(desiredTitle) · \(trimmedGroupName)"
    }

    private static func workspaceName(folderPath: String?, fallback: String) -> String {
        let fallbackName = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let folderPath else { return fallbackName }
        let pathName = URL(fileURLWithPath: folderPath).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return pathName.isEmpty ? fallbackName : pathName
    }

    private static func isDelegationToolCall(_ payload: ArchipelagoToolCall) -> Bool {
        if [payload.title, payload.kind]
            .compactMap({ $0?.lowercased() })
            .contains(where: { $0.contains("delegate_to_agent") }) {
            return true
        }
        guard let rawInput = payload.rawInput?.lowercased() else {
            return false
        }
        return rawInput.contains("agent_type") && rawInput.contains("task")
    }

    private static func delegationArguments(from rawInput: String?) -> (agentType: ArchipelagoAgentType?, task: String?)? {
        guard let rawInput = rawInput?.nilIfBlank,
              let data = rawInput.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) else {
            return nil
        }
        return findDelegationArguments(in: value)
    }

    private static func findDelegationArguments(
        in value: Any,
        depth: Int = 0
    ) -> (agentType: ArchipelagoAgentType?, task: String?)? {
        guard depth < 6 else { return nil }

        if let object = value as? [String: Any] {
            let agentTypeRaw = object["agent_type"] as? String ?? object["agentType"] as? String
            let task = object["task"] as? String
            if agentTypeRaw != nil || task != nil {
                let agentType = agentTypeRaw.map { ArchipelagoAgentType(rawValue: $0) ?? .unknown }
                return (agentType, task)
            }

            for key in ["arguments", "input", "raw_input", "rawInput", "params"] {
                if let nested = object[key],
                   let result = findDelegationArguments(in: nested, depth: depth + 1) {
                    return result
                }
            }
            for nested in object.values {
                if let result = findDelegationArguments(in: nested, depth: depth + 1) {
                    return result
                }
            }
        }

        if let array = value as? [Any] {
            for nested in array {
                if let result = findDelegationArguments(in: nested, depth: depth + 1) {
                    return result
                }
            }
        }

        if let string = value as? String,
           let data = string.data(using: .utf8),
           let nested = try? JSONSerialization.jsonObject(with: data) {
            return findDelegationArguments(in: nested, depth: depth + 1)
        }

        return nil
    }

    private static func delegationOutcomeSummary(from rawOutput: String?) -> String? {
        guard let rawOutput = rawOutput?.nilIfBlank else {
            return nil
        }
        guard let data = rawOutput.data(using: .utf8),
              let value = try? JSONSerialization.jsonObject(with: data) else {
            return responseSummary(from: rawOutput)
        }
        return delegationOutcomeSummary(fromValue: value)
    }

    private static func delegationOutcomeSummary(fromValue value: Any) -> String? {
        if let object = value as? [String: Any] {
            if let structured = object["structuredContent"] {
                return delegationOutcomeSummary(fromValue: structured)
            }
            if let content = object["content"] as? [[String: Any]] {
                let text = content
                    .compactMap { block -> String? in
                        guard block["type"] as? String == "text" else { return nil }
                        return block["text"] as? String
                    }
                    .joined(separator: "\n")
                if let summary = responseSummary(from: text) {
                    return summary
                }
            }

            let kind = (object["kind"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if kind == "ok", let summary = responseSummary(from: object["text"] as? String) {
                return summary
            }
            if kind == "err" {
                let code = (object["code"] as? String)?.nilIfBlank ?? "err"
                return "Agent 任务失败: \(code)"
            }

            for key in ["text", "summary", "message", "output"] {
                if let summary = responseSummary(from: object[key] as? String) {
                    return summary
                }
            }
        }

        if let string = value as? String {
            return responseSummary(from: string)
        }

        return nil
    }

    private static func parseServerDate(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) {
            return date
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func persistGroupChats() {
        groupStore.save(groupChats)
        notifyGroupChatsChanged()
    }

    private func notifyGroupChatsChanged() {
        onGroupChatsChanged?()
    }

    private static func responseSummary(from text: String?) -> String? {
        guard let text else { return nil }
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        guard !normalized.isEmpty else { return nil }
        let maxLength = 180
        guard normalized.count > maxLength else { return normalized }
        return String(normalized.prefix(maxLength)) + "..."
    }
}
