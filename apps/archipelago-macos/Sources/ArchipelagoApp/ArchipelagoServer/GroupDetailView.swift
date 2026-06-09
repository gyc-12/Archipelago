import SwiftUI

struct GroupDetailView: View {
    private static let horizontalPadding: CGFloat = 34

    let groupId: String
    let coordinator: ArchipelagoCoordinator
    var onOpenChat: () -> Void = {}
    var onOpenAgentChat: (GroupChat, GroupChat.GroupAgent) -> Void = { _, _ in }
    @State private var showsDeleteConfirmation = false
    @State private var taskDraft = ""

    private var group: GroupChat? { coordinator.group(byId: groupId) }
    private var trimmedTaskDraft: String {
        taskDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if let group {
                workspaceSummary(group)
                taskComposer(group)
                groupErrorView(group)
                agentList(group)
            } else {
                missingGroupView
            }
            bottomButtons
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, Self.horizontalPadding)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .task(id: groupId) {
            await coordinator.refreshGroupAgentRuntimeBindings(groupId: groupId)
        }
        .confirmationDialog("删除群聊？", isPresented: $showsDeleteConfirmation, titleVisibility: .visible) {
            Button("删除群聊", role: .destructive) {
                coordinator.deleteGroupChat(groupId: groupId)
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("会从 Island 和 Archipelago 工作区移除这个群聊，不会删除本地项目文件。")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: { coordinator.navigateBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArchipelagoDesign.onDarkSecondary)
            }
            .buttonStyle(.plain)
            Text(group?.name ?? "群聊")
                .font(ArchipelagoDesign.sectionHeaderFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                .lineLimit(1)
            Spacer()
        }
    }

    private func taskComposer(_ group: GroupChat) -> some View {
        let isSending = coordinator.isSendingGroupTask(groupId: group.id)
        let canSend = canSendGroupTask(group) && !isSending && !trimmedTaskDraft.isEmpty

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArchipelagoDesign.accent)
                Text("群聊任务")
                    .font(ArchipelagoDesign.rowTitleFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                Spacer()
                if let primary = group.primaryAgent {
                    HStack(spacing: 5) {
                        ArchipelagoAgentIconView(agentType: primary.agentType, size: 13)
                        Text("主 Agent")
                            .font(ArchipelagoDesign.badgeFont())
                            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("输入需求，主 Agent 会自动拆解并分派", text: $taskDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                    .lineLimit(1...4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                            .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                    )
                    .disabled(!canSendGroupTask(group) || isSending)
                    .onSubmit {
                        submitGroupTask(group)
                    }

                Button {
                    submitGroupTask(group)
                } label: {
                    ZStack {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                                .scaleEffect(0.58)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .frame(width: 28, height: 28)
                    .foregroundStyle(canSend ? Color.white : ArchipelagoDesign.onDarkTertiary)
                    .background(
                        canSend ? ArchipelagoDesign.accent : ArchipelagoDesign.onDarkSurface,
                        in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                            .strokeBorder(canSend ? ArchipelagoDesign.accent.opacity(0.35) : ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .help("发送群聊任务")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ArchipelagoDesign.onDarkSurfaceElevated, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func groupErrorView(_ group: GroupChat) -> some View {
        if let message = group.lastErrorMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
           !message.isEmpty {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ArchipelagoDesign.warning)
                Text(message)
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ArchipelagoDesign.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
            .overlay(
                RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                    .strokeBorder(ArchipelagoDesign.warning.opacity(0.24), lineWidth: 1)
            )
        }
    }

    private func canSendGroupTask(_ group: GroupChat) -> Bool {
        coordinator.isArchipelagoConnected &&
            group.folderId != nil &&
            group.primaryAgent?.conversationId != nil
    }

    private func submitGroupTask(_ group: GroupChat) {
        let text = trimmedTaskDraft
        guard !text.isEmpty,
              canSendGroupTask(group),
              !coordinator.isSendingGroupTask(groupId: group.id) else {
            return
        }
        taskDraft = ""
        coordinator.sendGroupTask(groupId: group.id, text: text)
    }

    private func agentList(_ group: GroupChat) -> some View {
        VStack(spacing: 6) {
            ForEach(group.agents) { agent in
                agentRow(agent, isPrimary: agent.id == group.primaryAgentId)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        guard agent.conversationId != nil else { return }
                        onOpenAgentChat(group, agent)
                    }
                    .help(agent.conversationId == nil
                        ? "这个 Agent 还没有绑定 Archipelago 会话"
                        : "双击打开 \(agent.agentType.displayName) 对话")
            }
            if group.agents.isEmpty {
                Text("暂无 Agent")
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
        }
    }

    private func workspaceSummary(_ group: GroupChat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(group.workspaceDisplayName)
                .font(ArchipelagoDesign.rowTitleFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
            if let folderPath = group.folderPath {
                Text(folderPath)
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ArchipelagoDesign.onDarkSurfaceElevated, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }

    private func agentRow(_ agent: GroupChat.GroupAgent, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 9) {
                ArchipelagoAgentIconView(agentType: agent.agentType, size: 17)

                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.agentType.displayName)
                        .font(ArchipelagoDesign.rowTitleFont())
                        .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                        .lineLimit(1)
                    Text(agent.role)
                        .font(ArchipelagoDesign.rowCaptionFont())
                        .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Button {
                    coordinator.setPrimaryAgent(groupId: groupId, agentId: agent.id)
                } label: {
                    Image(systemName: isPrimary ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isPrimary ? ArchipelagoDesign.warning : ArchipelagoDesign.onDarkTertiary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isPrimary)
                .help(isPrimary ? "当前主 Agent" : "设为主 Agent")

                Circle()
                    .fill(agent.displayStatus.dotColor)
                    .frame(width: 7, height: 7)

                Text(agent.displayStatus.overviewLabel)
                    .font(ArchipelagoDesign.badgeFont())
                    .foregroundStyle(agent.displayStatus == .working ? ArchipelagoDesign.success : ArchipelagoDesign.onDarkTertiary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ArchipelagoDesign.onDarkSurface, in: Capsule())
            }

            if let summary = latestSummary(for: agent) {
                ArchipelagoLatestResponseSummaryView(
                    agentType: agent.agentType,
                    summary: summary,
                    maxLines: 3
                )
            } else {
                Text(agentSubtitle(agent))
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }

    private var bottomButtons: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                showsDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ArchipelagoDesign.danger)
                    .frame(width: 27, height: 27)
                    .background(ArchipelagoDesign.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                            .strokeBorder(ArchipelagoDesign.danger.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(group == nil)
            .help("删除群聊")

            Spacer()

            Button(action: { coordinator.navigateToAddAgents(groupId: groupId) }) {
                Label("Agent", systemImage: "person.crop.circle.badge.plus")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .buttonStyle(.bordered)
            .tint(ArchipelagoDesign.onDarkSecondary)
            .controlSize(.small)
            .disabled(group == nil)
            .help("管理 Agent")

            Button(action: onOpenChat) {
                Label("对话", systemImage: "bubble.left.and.bubble.right")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
            }
            .buttonStyle(.borderedProminent)
            .tint(ArchipelagoDesign.accent)
            .controlSize(.small)
            .disabled(group?.archipelagoWorkspaceURL(baseURL: coordinator.archipelagoBaseURL) == nil)
            .help("打开 Archipelago 对话")
        }
    }

    private func agentSubtitle(_ agent: GroupChat.GroupAgent) -> String {
        var parts: [String] = []
        if let conversationId = agent.conversationId {
            parts.append("会话 #\(conversationId)")
        }
        parts.append(agent.workingDir)
        return parts.joined(separator: " · ")
    }

    private func latestSummary(for agent: GroupChat.GroupAgent) -> String? {
        guard let summary = agent.latestResponseSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !summary.isEmpty else {
            return nil
        }
        return summary
    }

    private var missingGroupView: some View {
        Text("群聊不存在")
            .font(ArchipelagoDesign.rowCaptionFont())
            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }
}
