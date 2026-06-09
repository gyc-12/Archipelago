import AppKit
import SwiftUI

struct CreateGroupChatView: View {
    @Bindable var coordinator: ArchipelagoCoordinator
    @State private var groupName = ""
    @State private var selectedAgentTypes: Set<ArchipelagoAgentType> = Set(ArchipelagoAgentType.agentHubMVPTypes)
    @State private var roleDrafts: [ArchipelagoAgentType: String] = Dictionary(
        uniqueKeysWithValues: ArchipelagoAgentType.agentHubMVPTypes.map { ($0, $0.defaultGroupRole) }
    )
    @State private var primaryAgentType: ArchipelagoAgentType = .claudeCode

    private var derivedName: String {
        coordinator.selectedFolderURL?.lastPathComponent ?? ""
    }

    private var resolvedName: String {
        let trimmed = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? derivedName : trimmed
    }

    private var selectableAgents: [ArchipelagoAgentInfo] {
        let agents = coordinator.availableAgents.filter { $0.available && $0.enabled && $0.agentType.isAgentHubMVPType }
        return ArchipelagoAgentType.agentHubMVPTypes.compactMap { type in
            agents.first(where: { $0.agentType == type })
        }
    }

    private var selectedMembers: [ArchipelagoGroupMemberDraft] {
        let selectableTypes = Set(selectableAgents.map(\.agentType))
        return ArchipelagoAgentType.agentHubMVPTypes
            .filter { selectedAgentTypes.contains($0) && selectableTypes.contains($0) }
            .map { type in
                ArchipelagoGroupMemberDraft(
                    agentType: type,
                    role: roleDrafts[type] ?? type.defaultGroupRole
                )
            }
    }

    private var effectivePrimaryAgentType: ArchipelagoAgentType {
        if selectedMembers.contains(where: { $0.agentType == primaryAgentType }) {
            return primaryAgentType
        }
        return selectedMembers.first?.agentType ?? primaryAgentType
    }

    private var canCreate: Bool {
        coordinator.selectedFolderURL != nil &&
            !resolvedName.isEmpty &&
            !selectedMembers.isEmpty &&
            !coordinator.isCreating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ArchipelagoDesign.spacingMd) {
            header
            if coordinator.isArchipelagoConnected {
                VStack(alignment: .leading, spacing: ArchipelagoDesign.spacingMd) {
                    folderPicker
                    nameField
                    agentSection
                    if let message = coordinator.creationErrorMessage {
                        errorBanner(message)
                    }
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)
                createButton
            } else {
                disconnectedView
            }
        }
        .padding(.horizontal, 46)
        .padding(.top, 10)
        .padding(.bottom, ArchipelagoDesign.spacingSm)
        .onChange(of: coordinator.selectedFolderURL) { _, newValue in
            if groupName.isEmpty {
                groupName = newValue?.lastPathComponent ?? ""
            }
        }
        .onChange(of: selectedAgentTypes) { _, newValue in
            if !newValue.contains(primaryAgentType),
               let first = ArchipelagoAgentType.agentHubMVPTypes.first(where: { newValue.contains($0) }) {
                primaryAgentType = first
            }
        }
        .onSubmit {
            submitCreate()
        }
    }

    private var header: some View {
        HStack(spacing: ArchipelagoDesign.spacingSm) {
            Button(action: { coordinator.navigateBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ArchipelagoDesign.onDarkSecondary)
            }
            .buttonStyle(.plain)
            Text("新建群聊")
                .font(ArchipelagoDesign.sectionHeaderFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
            Spacer()
        }
    }

    private var disconnectedView: some View {
        VStack(alignment: .leading, spacing: ArchipelagoDesign.spacingSm) {
            Text("内嵌 Archipelago 服务未连接")
                .font(ArchipelagoDesign.rowTitleFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
            Text(coordinator.connectionErrorMessage ?? "Archipelago 会自动启动包内 archipelago-server。请重试，或重新安装完整的 Archipelago.app。")
                .font(ArchipelagoDesign.rowCaptionFont())
                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                .fixedSize(horizontal: false, vertical: true)
            Button("重试连接") {
                coordinator.boot()
            }
            .buttonStyle(.bordered)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .padding(ArchipelagoDesign.spacingMd)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }

    private var folderPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("工作区")
            Button(action: pickFolder) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text(coordinator.selectedFolderURL?.path ?? "选择文件夹...")
                        .font(ArchipelagoDesign.rowCaptionFont())
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, ArchipelagoDesign.spacingSm)
                .padding(.vertical, 6)
                .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                        .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(coordinator.selectedFolderURL == nil ? ArchipelagoDesign.onDarkTertiary : ArchipelagoDesign.onDarkPrimary)
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("群聊名称")
            TextField("例如: 前端重构小组", text: $groupName)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                .padding(.horizontal, ArchipelagoDesign.spacingSm)
                .padding(.vertical, 7)
                .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                        .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                )
        }
    }

    private var agentSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel("Agent / 角色")
            if selectableAgents.isEmpty {
                Text("没有可用的 Agent")
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    .padding(.horizontal, ArchipelagoDesign.spacingSm)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                            .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                    )
            } else {
                ForEach(selectableAgents) { info in
                    agentDraftRow(info)
                }
            }
        }
    }

    private func agentDraftRow(_ info: ArchipelagoAgentInfo) -> some View {
        let type = info.agentType
        let isSelected = selectedAgentTypes.contains(type)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: ArchipelagoDesign.spacingSm) {
                Button(action: { toggleAgent(type) }) {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(isSelected ? ArchipelagoDesign.accent : ArchipelagoDesign.onDarkTertiary)
                }
                .buttonStyle(.plain)

                AgentChip(type: type, selected: isSelected)

                Spacer()

                Button(action: { primaryAgentType = type }) {
                    Image(systemName: effectivePrimaryAgentType == type ? "star.fill" : "star")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(effectivePrimaryAgentType == type ? ArchipelagoDesign.warning : ArchipelagoDesign.onDarkTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!isSelected)
                .help("默认打开的 Archipelago 会话")
            }

            if isSelected {
                HStack(spacing: 6) {
                    roleMenu(for: type)
                    TextField("角色", text: roleBinding(for: type))
                        .textFieldStyle(.plain)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                        .padding(.horizontal, ArchipelagoDesign.spacingSm)
                        .padding(.vertical, 5)
                        .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                        .overlay(
                            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                        )
                }
            }
        }
        .padding(.horizontal, ArchipelagoDesign.spacingSm)
        .padding(.vertical, 7)
        .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }

    private func roleMenu(for type: ArchipelagoAgentType) -> some View {
        Menu {
            ForEach(ArchipelagoGroupAgentRole.allCases) { role in
                Button(role.rawValue) {
                    roleDrafts[type] = role.rawValue
                }
            }
        } label: {
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ArchipelagoDesign.onDarkSecondary)
                .frame(width: 26, height: 26)
                .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                        .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }

    private var createButton: some View {
        HStack {
            if coordinator.isCreating {
                ProgressView()
                    .controlSize(.small)
                    .tint(ArchipelagoDesign.onDarkSecondary)
                Text("创建 Archipelago 会话...")
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
            }
            Spacer()
            Button("创建群聊") {
                submitCreate()
            }
            .buttonStyle(.borderedProminent)
            .tint(ArchipelagoDesign.accent)
            .disabled(!canCreate)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
        .padding(.top, 4)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(ArchipelagoDesign.rowCaptionFont())
            .foregroundStyle(ArchipelagoDesign.warning)
            .lineLimit(2)
            .padding(.horizontal, ArchipelagoDesign.spacingSm)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ArchipelagoDesign.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(ArchipelagoDesign.rowCaptionFont())
            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "选择工作区文件夹"
        panel.prompt = "选择"

        if panel.runModal() == .OK, let url = panel.url {
            coordinator.selectedFolderURL = url
        }
    }

    private func toggleAgent(_ type: ArchipelagoAgentType) {
        if selectedAgentTypes.contains(type) {
            guard selectedAgentTypes.count > 1 else { return }
            selectedAgentTypes.remove(type)
        } else {
            selectedAgentTypes.insert(type)
            roleDrafts[type, default: type.defaultGroupRole] = type.defaultGroupRole
        }
    }

    private func submitCreate() {
        guard canCreate, let url = coordinator.selectedFolderURL else { return }
        coordinator.createGroupChat(
            name: resolvedName,
            folderPath: url.path,
            members: selectedMembers,
            primaryAgentType: effectivePrimaryAgentType
        )
    }

    private func roleBinding(for type: ArchipelagoAgentType) -> Binding<String> {
        Binding(
            get: { roleDrafts[type] ?? type.defaultGroupRole },
            set: { roleDrafts[type] = $0 }
        )
    }
}

// MARK: - Add Agents

struct AddAgentsView: View {
    let groupId: String
    let coordinator: ArchipelagoCoordinator
    @State private var workingDir = FileManager.default.homeDirectoryForCurrentUser.path
    @State private var roleDraft = ArchipelagoGroupAgentRole.coder.rawValue

    private var group: GroupChat? { coordinator.group(byId: groupId) }
    private var currentAgentTypes: Set<ArchipelagoAgentType> {
        Set(group?.agents.map(\.agentType) ?? [])
    }
    private var addableAgents: [ArchipelagoAgentInfo] {
        coordinator.availableAgents.filter {
            $0.available &&
                $0.enabled &&
                $0.agentType.isAgentHubMVPType &&
                !currentAgentTypes.contains($0.agentType)
        }
    }
    private var defaultWorkingDir: String {
        group?.folderPath?.nilIfBlank ??
            group?.agents.first?.workingDir.nilIfBlank ??
            FileManager.default.homeDirectoryForCurrentUser.path
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            if group == nil {
                missingGroupView
            } else {
                dirField
                roleField
                agentButtons
                currentAgents
                doneButton
            }
        }
        .padding(.horizontal, 46)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .onAppear(perform: syncWorkingDirWithGroup)
        .onChange(of: group?.folderPath) { _, _ in
            syncWorkingDirWithGroup()
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
            Text(group?.name ?? "添加 Agent")
                .font(ArchipelagoDesign.sectionHeaderFont())
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
            Spacer()
        }
    }

    private var dirField: some View {
        HStack(spacing: 6) {
            fieldLabel("目录")
                .frame(width: 32, alignment: .trailing)
            TextField("工作目录", text: $workingDir)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                .padding(.horizontal, ArchipelagoDesign.spacingSm)
                .padding(.vertical, 6)
                .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                        .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                )
        }
    }

    private var roleField: some View {
        HStack(spacing: 6) {
            fieldLabel("角色")
                .frame(width: 32, alignment: .trailing)
            TextField("角色", text: $roleDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                .padding(.horizontal, ArchipelagoDesign.spacingSm)
                .padding(.vertical, 6)
                .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                        .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                )
        }
    }

    private var agentButtons: some View {
        VStack(alignment: .leading, spacing: 6) {
            fieldLabel("点击添加 Agent")
            if addableAgents.isEmpty {
                Text("当前群聊已添加全部可用 Agent")
                    .font(ArchipelagoDesign.rowCaptionFont())
                    .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                    .padding(.horizontal, ArchipelagoDesign.spacingSm)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
                    .overlay(
                        RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                            .strokeBorder(ArchipelagoDesign.onDarkBorder, lineWidth: 1)
                    )
            } else {
                HStack(spacing: 8) {
                    ForEach(addableAgents) { info in
                        Button(action: {
                            coordinator.addAgentToGroup(
                                groupId: groupId,
                                agentType: info.agentType,
                                workingDir: workingDir.nilIfBlank ?? defaultWorkingDir,
                                role: roleDraft
                            )
                        }) {
                            AgentChip(type: info.agentType, selected: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var currentAgents: some View {
        if let group, !group.agents.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                fieldLabel("已添加")
                ForEach(group.agents) { agent in
                    HStack(spacing: 8) {
                        ArchipelagoAgentIconView(agentType: agent.agentType, size: 14)
                        Circle().fill(agent.displayStatus.dotColor).frame(width: 7, height: 7)
                        Text(agent.agentType.displayName)
                            .font(ArchipelagoDesign.rowTitleFont())
                            .foregroundStyle(ArchipelagoDesign.onDarkPrimary)
                        Text(agent.role)
                            .font(ArchipelagoDesign.rowCaptionFont())
                            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                        Spacer()
                        Button(action: { coordinator.removeAgentFromGroup(groupId: groupId, agentId: agent.id) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var missingGroupView: some View {
        Text("群聊不存在")
            .font(ArchipelagoDesign.rowCaptionFont())
            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private var doneButton: some View {
        HStack {
            Spacer()
            Button("完成") { coordinator.navigateBack() }
                .buttonStyle(.borderedProminent)
                .tint(ArchipelagoDesign.accent)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(ArchipelagoDesign.rowCaptionFont())
            .foregroundStyle(ArchipelagoDesign.onDarkTertiary)
    }

    private func syncWorkingDirWithGroup() {
        if workingDir == FileManager.default.homeDirectoryForCurrentUser.path || workingDir.nilIfBlank == nil {
            workingDir = defaultWorkingDir
        }
    }
}

// MARK: - Shared Chip

struct AgentChip: View {
    let type: ArchipelagoAgentType
    let selected: Bool

    private var color: Color {
        ArchipelagoDesign.agentColor(type)
    }

    var body: some View {
        HStack(spacing: 5) {
            ArchipelagoAgentIconView(agentType: type, size: 13)
            Text(type.shortName)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(selected ? ArchipelagoDesign.onDarkPrimary : ArchipelagoDesign.onDarkSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(selected ? color.opacity(0.35) : ArchipelagoDesign.onDarkSurface, in: RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: ArchipelagoDesign.radiusSm)
                .strokeBorder(selected ? color : ArchipelagoDesign.onDarkBorder, lineWidth: 1)
        )
    }
}
