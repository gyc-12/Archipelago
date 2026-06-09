# 修复外观设置响应式 + 新增 UI 个性化选项

## Goal

修复外观设置页面中的响应式问题（rightSlot/centerLabel 点击无效），删除无用的 completedStaleThreshold 设置，并设计新的 UI 个性化选项以丰富用户自定义体验。

## What I already know

* **问题诊断**：
  - `editingPreferences` 是计算属性：`model.appearancePreferences(for: editingProfile)`
  - AppModel 中 `notchAppearancePreferences` / `topBarAppearancePreferences` 有 `didSet`，会触发持久化
  - 但 `updateAppearancePreferences()` 修改的是这些属性，UI 应该会刷新（AppModel 是 `@Observable`）
  - 可能问题：previewSection 使用了 `editingPreferences` 但没有观察到变化
  
* **用户需求**：
  - ✅ 修复 rightSlot / centerLabel 设置点击无效
  - ✅ 删除 completedStaleThreshold 设置
  - 💡 头脑风暴新的 UI 个性化选项（集中在 UI 层面）

* **现有设置项**：
  - rightSlot (count/agents/none) — 关闭时右侧内容
  - centerLabel (sessionName/agentAction/off) — 外接屏中央标签
  - groupChatSort (name/recentActivity/createdAt) — 群聊排序
  - ~~completedStaleThreshold~~ — 待删除

## Assumptions (temporary)

* 响应式问题可能是因为预览部分没有正确观察 model 变化
* 删除 completedStaleThreshold 后，可能需要移除相关的 UI 代码和持久化逻辑
* 新的 UI 个性化选项应该聚焦在视觉呈现、布局密度、动效等用户可感知的元素

## Open Questions

* rightSlot/centerLabel 的响应式问题具体原因？（需要进一步检查 SwiftUI 响应式机制）
* 新的 UI 个性化选项有哪些可能性？（需要头脑风暴）

## Requirements

**✅ 用户确认：基础套餐（显示密度/布局）**

### 1. 修复响应式问题
- **根本原因**：`editingPreferences` 是计算属性，虽然 AppModel 是 `@Observable`，但预览部分可能没有正确触发重新计算
- **解决方案**：确保 SwiftUI 检测到 model 变化并重新渲染预览（可能需要添加显式依赖或使用 `@State` 缓存）

### 2. 删除 completedStaleThreshold
- 从 `IslandAppearancePreferences` 中移除 `completedStaleThreshold` 字段
- 从 AppModel 中移除相关属性、持久化逻辑
- 从 AppearanceSettingsPane 中移除 `staleThresholdSection`
- 删除本地化字符串（zh-Hans / en）

### 3. 新增 UI 个性化选项

#### 3.1 群聊列表间距
```swift
enum GroupChatListSpacing: String, CaseIterable, Identifiable {
    case compact   // 紧凑：6px 行间距，8px 内边距
    case standard  // 标准：当前默认值
    case relaxed   // 宽松：10px 行间距，14px 内边距
}
```

#### 3.2 Agent Badge 显示
```swift
enum AgentBadgeDisplay: String, CaseIterable, Identifiable {
    case all       // 全部显示（默认）
    case primaryOnly  // 仅主 agent（只显示标有星标的）
}
```

### 4. 接线到 GroupChatListView
- 添加参数：`spacing: GroupChatListSpacing`, `badgeDisplay: AgentBadgeDisplay`
- 在 `chatList` 中应用间距设置
- 在 `GroupChatRow` 中根据 `badgeDisplay` 过滤显示的 agent badges

### 5. 更新设置界面
- 新增 `listSpacingSection`（3 个选项卡片）
- 新增 `agentBadgeSection`（2 个选项卡片）
- 更新预览以反映新设置

## Acceptance Criteria

* [ ] rightSlot 设置点击后，预览立即更新（响应式问题已修复）
* [ ] centerLabel 设置点击后，预览立即更新（响应式问题已修复）
* [ ] completedStaleThreshold 相关代码已删除（数据模型、AppModel、UI、本地化）
* [ ] 新增 GroupChatListSpacing enum（compact/standard/relaxed）
* [ ] 新增 AgentBadgeDisplay enum（all/primaryOnly）
* [ ] GroupChatListView 接收并应用 spacing 和 badgeDisplay 参数
* [ ] IslandPanelView 传递这些参数到 GroupChatListView
* [ ] 设置界面新增 2 个 section（列表间距、agent badge 显示）
* [ ] 本地化字符串更新（删除 staleThreshold，新增 spacing/badgeDisplay）
* [ ] 修改设置后，群聊列表的间距和 badge 显示立即改变

## Definition of Done (team quality bar)

* 代码编译通过
* 设置修改后立即在预览和实际 UI 中生效
* 本地化字符串更新
* 无死代码残留

## Out of Scope (explicit)

* 不修改 GroupChatListView 的核心布局（只添加参数）
* 不添加复杂动画系统

## Technical Notes

* 关键文件：
  - `apps/archipelago-macos/Sources/ArchipelagoApp/Views/AppearanceSettingsPane.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/AppModel.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/AppModelTypes.swift`
