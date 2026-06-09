import SwiftUI

struct GroupChatListView: View {
    let coordinator: ArchipelagoCoordinator
    var sortOrder: GroupChatSort = .recentActivity
    var spacing: GroupChatListSpacing = .standard
    var badgeDisplay: AgentBadgeDisplay = .all
    var onOpenDetail: (GroupChat) -> Void = { _ in }
    var onOpenChat: (GroupChat) -> Void = { _ in }

    private var sortedGroups: [GroupChat] {
        switch sortOrder {
        case .name:
            return coordinator.groupChats.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .recentActivity:
            return coordinator.groupChats.sorted {
                ($0.latestCompletedAgent?.latestResponseAt ?? .distantPast) >
                ($1.latestCompletedAgent?.latestResponseAt ?? .distantPast)
            }
        case .createdAt:
            return coordinator.groupChats.sorted { $0.createdAt > $1.createdAt }
        }
    }

    var body: some View {
        VStack(spacing: ArchipelagoDesign.spacingSm) {
            header
            if coordinator.isLoading {
                loadingView
            } else if !coordinator.isArchipelagoConnected {
                disconnectedView
            } else if coordinator.groupChats.isEmpty {
                emptyView
            } else {
                chatList
            }
        }
        .padding(.horizontal, 46)
        .padding(.top, 10)
        .padding(.bottom, ArchipelagoDesign.spacingSm)
    }

    private var header: some View {
        HStack(spacing: ArchipelagoDesign.spacingSm) {
            Button(action: { coordinator.navigateToCreate() }) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ArchipelagoDesign.onDarkSecondary)
            }
            .buttonStyle(.plain)
            Text("我的群聊")
                .font(ArchipelagoDesign.sectionHeaderFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
            Spacer()
            Text("\(coordinator.groupChats.count)")
                .font(ArchipelagoDesign.rowCaptionFont())
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
        }
    }

    private var loadingView: some View {
        VStack(spacing: ArchipelagoDesign.spacingSm) {
            Spacer()
            ProgressView().tint(ArchipelagoDesign.onDarkTertiary)
            Text("连接 archipelago-server...")
                .font(ArchipelagoDesign.captionFont())
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: ArchipelagoDesign.spacingSm) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ArchipelagoDesign.warning)
            Text("内嵌 Archipelago 服务未连接")
                .font(ArchipelagoDesign.rowTitleFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
            Text(coordinator.connectionErrorMessage ?? "Archipelago 会自动启动包内 archipelago-server。")
                .font(ArchipelagoDesign.rowCaptionFont())
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("重试连接") {
                coordinator.boot()
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(spacing: ArchipelagoDesign.spacingSm) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 24))
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
            Text("暂无群聊，点 + 新建")
                .font(ArchipelagoDesign.captionFont())
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var chatList: some View {
        LazyVStack(spacing: spacing.rowSpacing) {
            ForEach(sortedGroups) { group in
                GroupChatRow(group: group, padding: spacing.rowPadding, badgeDisplay: badgeDisplay)
                    .onTapGesture(count: 2) { onOpenChat(group) }
                    .onTapGesture(count: 1) { onOpenDetail(group) }
            }
        }
    }
}

private struct GroupChatRow: View {
    let group: GroupChat
    var padding: CGFloat = 11
    var badgeDisplay: AgentBadgeDisplay = .all

    /// Derive the aggregate display status for the group row's status dot.
    /// Priority: working > blocked > idle > offline
    private var aggregateStatus: AgentDisplayStatus {
        let statuses = group.agents.map(\.displayStatus)
        if statuses.contains(.working) { return .working }
        if statuses.contains(.blocked) { return .blocked }
        if statuses.contains(.idle) { return .idle }
        return .offline
    }

    private var displayedAgents: [GroupChat.GroupAgent] {
        switch badgeDisplay {
        case .all:
            return group.agents
        case .primaryOnly:
            return group.agents.filter { $0.id == group.primaryAgentId }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(group.name)
                    .font(ArchipelagoDesign.rowTitleFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                    .lineLimit(1)
                Text(group.workspaceDisplayName)
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    .lineLimit(1)
                FlowLayout(spacing: 4) {
                    ForEach(displayedAgents) { agent in
                        AgentBadge(
                            agentType: agent.agentType,
                            status: agent.status,
                            role: agent.role,
                            isPrimary: agent.id == group.primaryAgentId
                        )
                    }
                    if displayedAgents.isEmpty {
                        Text("无 Agent")
                            .font(ArchipelagoDesign.rowCaptionFont())
                            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    }
                }
            }
            Spacer()
            Circle()
                .fill(aggregateStatus.dotColor)
                .frame(width: 7, height: 7)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, padding)
        .background(ArchipelagoDesign.onDarkSurfaceElevated, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            totalWidth = max(totalWidth, currentX - spacing)
        }
        let totalHeight = currentY + lineHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.minX + maxWidth && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct AgentBadge: View {
    let agentType: ArchipelagoAgentType
    let status: ArchipelagoConnectionStatus
    let role: String
    let isPrimary: Bool

    private var color: Color {
        ArchipelagoDesign.agentColor(agentType)
    }

    var body: some View {
        HStack(spacing: 5) {
            ArchipelagoAgentIconView(agentType: agentType, size: 13)
            if isPrimary {
                Image(systemName: "star.fill")
                    .font(.system(size: 7, weight: .bold))
            }
            Text(agentType.shortName)
            Text(role)
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
        }
        .font(ArchipelagoDesign.badgeFont())
        .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            color.opacity(status == .connected ? 0.24 : 0.12),
            in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(color.opacity(status == .connected ? 0.30 : 0.18), lineWidth: 1)
        )
    }
}
