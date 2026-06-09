import SwiftUI
import MarkdownUI

struct ChatWindowView: View {
    let group: GroupChat
    let coordinator: ArchipelagoCoordinator
    @State private var draft = ""
    @State private var messages: [ChatDisplayMessage] = []
    @State private var permissionRequest: ArchipelagoPermissionRequest?

    private var firstConnectionId: String? {
        group.agents.first(where: { $0.connectionId != nil })?.connectionId
    }

    var body: some View {
        VStack(spacing: 0) {
            messageList
            Divider()
            if let perm = permissionRequest {
                approvalBar(perm)
            }
            inputBar
            statusBar
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 400, idealHeight: 640)
        .background(Color(red: 0.008, green: 0.024, blue: 0.09))
        .preferredColorScheme(.dark)
        .task { connectAndListen() }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(messages) { msg in
                        ChatMessageRow(message: msg)
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom") }
            }
        }
    }

    // MARK: - Approval Bar

    private func approvalBar(_ perm: ArchipelagoPermissionRequest) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 14))
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("请求许可").font(.system(size: 11, weight: .semibold, design: .monospaced)).foregroundStyle(.orange)
                Text(perm.toolCall?.title ?? "tool").font(.system(size: 12, weight: .medium, design: .monospaced)).lineLimit(1)
            }
            Spacer()
            ForEach(perm.options) { opt in
                Button(opt.label) {
                    Task { await respondPermission(perm.requestId, optionId: opt.id) }
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .buttonStyle(.borderedProminent)
                .tint(opt.id == "deny" ? .gray : .accentColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.06))
    }

    // MARK: - Input Bar (Archipelago style)

    private var inputBar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Send a message...", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1.5)
                    )
                    .onSubmit(send)

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(draft.isEmpty ? Color.gray : Color.orange)
                }
                .buttonStyle(.plain)
                .disabled(draft.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Status Bar (project + branch)

    private var statusBar: some View {
        HStack(spacing: 12) {
            if let dir = group.agents.first?.workingDir {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 9))
                    Text(URL(fileURLWithPath: dir).lastPathComponent)
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
            ForEach(group.agents) { agent in
                AgentChip(type: agent.agentType, selected: agent.status == .connected)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Actions

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let connId = firstConnectionId else { return }
        draft = ""
        messages.append(ChatDisplayMessage(id: UUID().uuidString, role: .user, agentType: nil, text: text, toolCalls: [], delegation: nil, isStreaming: false))
        Task {
            try? await coordinator.client?.prompt(connectionId: connId, text: text, folderId: group.folderId)
        }
    }

    private func respondPermission(_ requestId: String, optionId: String) async {
        guard let connId = firstConnectionId else { return }
        try? await coordinator.client?.respondPermission(connectionId: connId, requestId: requestId, optionId: optionId)
        permissionRequest = nil
    }

    // MARK: - WebSocket

    private func connectAndListen() {
        guard let ws = coordinator.wsClient else { return }
        for agent in group.agents {
            guard let connId = agent.connectionId else { continue }
            let subId = "chat-\(group.id)-\(connId)"
            ws.onEvent = { sid, eventType, data in
                guard sid == subId else { return }
                Task { @MainActor in self.handleEvent(eventType, data: data, agentType: agent.agentType) }
            }
            ws.onSnapshot = { sid, _ in guard sid == subId else { return } }
            ws.attach(subscriptionId: subId, connectionId: connId)
        }
    }

    private func handleEvent(_ type: String, data: Data, agentType: ArchipelagoAgentType) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        switch type {
        case "content_delta":
            if let d = try? decoder.decode(ArchipelagoContentDelta.self, from: data) { appendOrStreamText(d.text, agentType: agentType) }
        case "tool_call":
            if let tc = try? decoder.decode(ArchipelagoToolCall.self, from: data) { appendToolCall(tc) }
        case "permission_request":
            if let p = try? decoder.decode(ArchipelagoPermissionRequest.self, from: data) { permissionRequest = p }
        case "permission_resolved":
            permissionRequest = nil
        case "delegation_started":
            if let d = try? decoder.decode(ArchipelagoDelegationStarted.self, from: data) { appendDelegation(d) }
        case "turn_complete":
            finishStreaming()
        default: break
        }
    }

    private func appendOrStreamText(_ text: String, agentType: ArchipelagoAgentType) {
        if let last = messages.last, last.role == .agent, last.isStreaming, last.agentType == agentType {
            messages[messages.count - 1].text += text
        } else {
            messages.append(ChatDisplayMessage(id: UUID().uuidString, role: .agent, agentType: agentType, text: text, toolCalls: [], delegation: nil, isStreaming: true))
        }
    }

    private func appendToolCall(_ tc: ArchipelagoToolCall) {
        guard !messages.isEmpty, messages.last?.role == .agent else { return }
        messages[messages.count - 1].toolCalls.append(
            ChatDisplayMessage.ToolCallDisplay(id: tc.id, title: tc.title ?? "tool", status: tc.status ?? "running", content: tc.content)
        )
    }

    private func appendDelegation(_ del: ArchipelagoDelegationStarted) {
        guard !messages.isEmpty, messages.last?.role == .agent else { return }
        messages[messages.count - 1].delegation = ChatDisplayMessage.DelegationDisplay(childAgent: del.childAgentType, task: del.task ?? "", completed: false)
    }

    private func finishStreaming() {
        if !messages.isEmpty, messages.last?.isStreaming == true {
            messages[messages.count - 1].isStreaming = false
        }
    }
}

// MARK: - Message Row (Archipelago style)

private struct ChatMessageRow: View {
    let message: ChatDisplayMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 6) {
                content
                toolCalls
                delegation
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(message.role == .user ? Color.secondary.opacity(0.06) : Color.clear)
    }

    @ViewBuilder
    private var avatar: some View {
        if message.role == .user {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "person.fill").font(.system(size: 12)).foregroundColor(.accentColor))
        } else {
            Circle()
                .fill(agentColor.opacity(0.2))
                .frame(width: 28, height: 28)
                .overlay(Image(systemName: "cpu").font(.system(size: 12)).foregroundStyle(agentColor))
        }
    }

    private var agentColor: Color {
        guard let type = message.agentType else { return .secondary }
        switch type {
        case .claudeCode: return Color(red: 0.91, green: 0.51, blue: 0.23)
        case .codex: return Color(red: 0.22, green: 0.71, blue: 0.42)
        case .openCode: return Color(red: 0.48, green: 0.42, blue: 0.96)
        default: return .secondary
        }
    }

    @ViewBuilder
    private var content: some View {
        if message.role == .user {
            Text(message.text)
                .font(.system(size: 13, design: .monospaced))
                .textSelection(.enabled)
        } else {
            Markdown(message.text)
                .markdownTextStyle { FontSize(13) }
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var toolCalls: some View {
        if !message.toolCalls.isEmpty {
            ToolCallGroup(toolCalls: message.toolCalls)
        }
    }

    @ViewBuilder
    private var delegation: some View {
        if let del = message.delegation {
            DelegationCard(delegation: del)
        }
    }
}

// MARK: - Tool Call Group (Archipelago "> Ran N commands" style)

private struct ToolCallGroup: View {
    let toolCalls: [ChatDisplayMessage.ToolCallDisplay]
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("Ran \(toolCalls.count) command\(toolCalls.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(toolCalls) { tc in
                        HStack(spacing: 6) {
                            Circle().fill(tc.status == "completed" ? .green : .orange).frame(width: 6, height: 6)
                            Text(tc.title)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(.primary)
                            if let content = tc.content {
                                Text(content)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.1), lineWidth: 1))
                .padding(.top, 4)
            }
        }
    }
}

// MARK: - Delegation Card (Archipelago style)

private struct DelegationCard: View {
    let delegation: ChatDisplayMessage.DelegationDisplay
    @State private var isExpanded = false

    private var agentColor: Color {
        switch delegation.childAgent {
        case .claudeCode: return Color(red: 0.91, green: 0.51, blue: 0.23)
        case .codex: return Color(red: 0.22, green: 0.71, blue: 0.42)
        case .openCode: return Color(red: 0.48, green: 0.42, blue: 0.96)
        default: return .secondary
        }
    }

    private var agentLabel: String {
        switch delegation.childAgent {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .openCode: return "OpenCode"
        default: return delegation.childAgent.rawValue
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isExpanded.toggle() } }) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(agentColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "cpu")
                                .font(.system(size: 14))
                                .foregroundStyle(agentColor)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(agentLabel)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            HStack(spacing: 3) {
                                Image(systemName: delegation.completed ? "checkmark.circle.fill" : "clock")
                                    .font(.system(size: 10))
                                    .foregroundStyle(delegation.completed ? .green : .orange)
                                Text(delegation.completed ? "done" : "running")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(delegation.completed ? .green : .orange)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (delegation.completed ? Color.green : Color.orange).opacity(0.1),
                                in: Capsule()
                            )
                        }
                        Text(delegation.task)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                Text("子 Agent 执行详情...")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1))
    }
}
