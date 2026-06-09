# 完整方案总结

## 目标
1. 修复 rightSlot/centerLabel 设置响应式问题
2. 删除无用的 completedStaleThreshold 设置
3. 新增 2 个 UI 个性化选项（群聊列表间距、agent badge 显示）

## 改动清单

### 1. 修复响应式问题
**问题**：点击 rightSlot/centerLabel 设置后，预览不更新

**根本原因**：
- `editingPreferences` 是计算属性，每次访问重新计算
- AppModel 是 `@Observable`，修改 `notchAppearancePreferences`/`topBarAppearancePreferences` 会触发 `didSet`
- 但预览可能因为 SwiftUI 优化而没有重新渲染

**解决方案**：
- 检查 `previewRightContent` / `previewCenterLabel` 的依赖链
- 可能需要在 `previewSection` 中添加 `.id(editingProfile)` 或显式依赖
- 或者将 `editingPreferences` 改为 `@State` 并在 `onAppear`/`onChange` 中同步

### 2. 删除 completedStaleThreshold
**移除位置**：
- `AppModelTypes.swift`：从 `IslandAppearancePreferences` 中删除字段，删除 `IslandCompletedStaleThreshold` enum
- `AppModel.swift`：删除 `completedStaleThreshold` 相关持久化逻辑
- `AppearanceSettingsPane.swift`：删除 `staleThresholdSection` 和相关方法
- `IslandPanelView.swift`：检查是否有使用 `completedStaleThreshold` 的地方（之前看到 line 591, 633, 683, 741）
- `Localizable.strings`：删除 `settings.appearance.staleThreshold.*` 相关键

### 3. 新增群聊列表间距选项

**数据模型**（AppModelTypes.swift）：
```swift
enum GroupChatListSpacing: String, CaseIterable, Identifiable, Sendable {
    case compact   // 紧凑
    case standard  // 标准（默认）
    case relaxed   // 宽松
    
    var id: String { rawValue }
    
    var rowSpacing: CGFloat {
        switch self {
        case .compact: return 4
        case .standard: return 6
        case .relaxed: return 10
        }
    }
    
    var rowPadding: CGFloat {
        switch self {
        case .compact: return 8
        case .standard: return 11  // 当前默认
        case .relaxed: return 14
        }
    }
}
```

### 4. 新增 Agent Badge 显示选项

**数据模型**（AppModelTypes.swift）：
```swift
enum AgentBadgeDisplay: String, CaseIterable, Identifiable, Sendable {
    case all          // 全部显示
    case primaryOnly  // 仅主 agent
    
    var id: String { rawValue }
}
```

### 5. 接线到 GroupChatListView

**GroupChatListView.swift**：
```swift
struct GroupChatListView: View {
    var sortOrder: GroupChatSort = .recentActivity
    var spacing: GroupChatListSpacing = .standard
    var badgeDisplay: AgentBadgeDisplay = .all
    
    private var chatList: some View {
        LazyVStack(spacing: spacing.rowSpacing) {  // 应用间距
            ForEach(sortedGroups) { group in
                GroupChatRow(
                    group: group, 
                    badgeDisplay: badgeDisplay,
                    padding: spacing.rowPadding
                )
                // ...
            }
        }
    }
}

private struct GroupChatRow: View {
    let group: GroupChat
    let badgeDisplay: AgentBadgeDisplay
    let padding: CGFloat
    
    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                // ...
                FlowLayout(spacing: 4) {
                    ForEach(displayedAgents) { agent in  // 过滤
                        AgentBadge(...)
                    }
                }
            }
            // ...
        }
        .padding(.horizontal, 12)
        .padding(.vertical, padding)  // 应用内边距
    }
    
    private var displayedAgents: [GroupChat.GroupAgent] {
        switch badgeDisplay {
        case .all:
            return group.agents
        case .primaryOnly:
            return group.agents.filter { $0.id == group.primaryAgentId }
        }
    }
}
```

### 6. 更新设置界面

**AppearanceSettingsPane.swift**：
- 删除 `staleThresholdSection`
- 新增 `listSpacingSection`（3 个选项卡片：紧凑/标准/宽松）
- 新增 `agentBadgeSection`（2 个选项卡片：全部显示/仅主 agent）
- 在 `sessionListPersonalizationPart` 中调用这些新 section

### 7. 本地化字符串

**删除**：
- `settings.appearance.staleThreshold.title`
- `settings.appearance.staleThreshold.note`
- `settings.appearance.staleThreshold.twoMinutes`
- `settings.appearance.staleThreshold.fiveMinutes`
- `settings.appearance.staleThreshold.tenMinutes`
- `settings.appearance.staleThreshold.twentyMinutes`
- `settings.appearance.staleThreshold.never`

**新增**：
- `settings.appearance.listSpacing.title` = "07 · 列表间距" / "07 · List spacing"
- `settings.appearance.listSpacing.note` = "控制群聊列表的紧凑程度。" / "Control group chat list density."
- `settings.appearance.listSpacing.compact` = "紧凑" / "Compact"
- `settings.appearance.listSpacing.standard` = "标准" / "Standard"
- `settings.appearance.listSpacing.relaxed` = "宽松" / "Relaxed"
- `settings.appearance.agentBadge.title` = "08 · Agent 显示" / "08 · Agent display"
- `settings.appearance.agentBadge.note` = "选择群聊列表中显示哪些 agent。" / "Choose which agents to show in list."
- `settings.appearance.agentBadge.all` = "全部显示" / "All agents"
- `settings.appearance.agentBadge.primaryOnly` = "仅主 Agent" / "Primary only"

## 验证方式
1. 打开设置 → 个性化
2. 点击 rightSlot / centerLabel 选项，确认预览立即更新
3. 切换列表间距（紧凑/标准/宽松），打开 Island 确认群聊列表间距改变
4. 切换 agent 显示（全部/仅主），确认只显示主 agent（带星标）

这个方案清晰吗？如果没问题，我将准备 jsonl 并开始实现。
