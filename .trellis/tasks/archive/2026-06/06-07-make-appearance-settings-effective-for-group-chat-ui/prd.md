# 让外观设置生效：适配群聊界面

## Goal

外观设置页面中有多个个性化设置项（usageDisplay、sessionStateIndicator、sessionGroup、sessionSort、staleThreshold），这些设置原本是为"会话列表"（session list）设计的，但现在 Island 实际展示的是"群聊列表"（GroupChatListView）。需要检查哪些设置已过期/未接线，设计适合群聊界面的个性化选项，并让它们真正生效。

## What I already know

* **审计结果（接线状态）**：
  - ✅ **已生效**：`rightSlot`（关闭时右侧内容）、`centerLabel`（外接屏中央标签）、`completedStaleThreshold`（完成超时）
  - ❌ **未接线**：`usageDisplay`、`sessionStateIndicator`、`sessionGroup`、`sessionSort` — 这些设置虽然有 UI、有持久化，但 `GroupChatListView` 完全没有使用它们
  - 📍 **接线位置**：IslandPanelView line 455-465 调用 `GroupChatListView(coordinator:onOpenDetail:onOpenChat:)` 时未传递任何外观偏好参数

* **当前文件结构**：
  - `AppearanceSettingsPane.swift`：设置界面，包含多个设置项 section（line 138-142: usageDisplay, stateIndicator, sessionGroup, sessionSort, staleThreshold）
  - `AppModelTypes.swift`：偏好设置数据模型，定义了 `IslandAppearancePreferences` 及各种 enum
  - `IslandPanelView.swift`：Island 实际 UI，line 455 使用 `GroupChatListView`
  - `GroupChatListView.swift`：群聊列表实现，当前只接收 `coordinator`、`onOpenDetail`、`onOpenChat` 参数

* **已发现的问题**：
  - 注释说明"v6 redesign round"砍掉了一些功能（idle behavior, per-tool agent colors, spinner, custom avatars）
  - 设置项命名都带"session"（sessionStateIndicator、sessionGroup 等），但现在用的是群聊列表
  - 4 个设置项（usageDisplay、sessionStateIndicator、sessionGroup、sessionSort）完全是死代码

## Assumptions (temporary)

* 群聊列表与会话列表有不同的个性化需求
* 原有的 session-specific 设置应该移除或适配为群聊场景
* 需要让用户配置的是有实际价值的选项（避免为了配置而配置）

## Open Questions

* rightSlot / centerLabel 设置是否已经生效？（检查 V6NotchContent.swift）
* GroupChatListView 是否接收了任何外观偏好参数？（检查初始化调用）
* 哪些设置项对群聊列表有意义，哪些已过期？
* 群聊列表需要什么新的个性化选项？（排序、过滤、显示密度等）

## Requirements

**✅ 用户确认：适度接线方案 + 基础排序**

### 1. 保留已生效的设置
- `rightSlot` (count/agents/none) — 已接线到 V6NotchContent
- `centerLabel` (sessionName/agentAction/off) — 已接线到 V6NotchContent
- `completedStaleThreshold` (2/5/10/20min/never) — 已接线到 IslandPanelView

### 2. 移除无用设置
从 `IslandAppearancePreferences` / `AppModel` / `AppearanceSettingsPane` 中移除：
- ❌ `usageDisplay` (hidden/compact) — 对群聊列表无意义
- ❌ `sessionStateIndicator` (animatedDot/bar/glyph/tint) — 群聊列表不展示会话状态
- ❌ `sessionGroup` (none/state/agent/project) — 群聊列表不需要分组

### 3. 重命名并接线排序设置
- 将 `sessionSort` 改名为 `groupChatSort`
- 新增排序选项 enum：
  ```swift
  enum GroupChatSort: String, CaseIterable, Identifiable {
      case name         // 按名称 A-Z
      case recentActivity  // 按最近活动时间
      case createdAt    // 按创建时间
  }
  ```
- 在 `GroupChatListView` 中接收并应用排序参数
- 更新 `AppearanceSettingsPane` 中的排序设置 UI（3 个选项）

### 4. 更新本地化
- 删除：usageDisplay、sessionStateIndicator、sessionGroup 相关字符串
- 修改：sessionSort → groupChatSort，并更新选项文本（name/recentActivity/createdAt）

### 5. 更新预览
- `AppearanceSettingsPane` 的预览只保留排序设置
- 移除 usageDisplay / stateIndicator / sessionGroup 的预览部分

## Acceptance Criteria

* [ ] 移除了 usageDisplay、sessionStateIndicator、sessionGroup 相关代码（AppModelTypes、AppModel、AppearanceSettingsPane）
* [ ] sessionSort 重命名为 groupChatSort，新增 3 种排序选项（name/recentActivity/createdAt）
* [ ] GroupChatListView 接收并应用 groupChatSort 参数
* [ ] IslandPanelView 传递 groupChatSort 到 GroupChatListView
* [ ] 排序设置在 AppearanceSettingsPane 中更新为 3 选项卡片
* [ ] 预览中移除了 usageDisplay、stateIndicator、sessionGroup 部分
* [ ] 本地化字符串更新（中英文）
* [ ] 修改排序设置后，实际群聊列表顺序发生变化

## Definition of Done (team quality bar)

* 代码编译通过
* 设置修改后能在 Island UI 中看到实际效果
* 本地化字符串更新（如果有新设置项）
* 无冗余/死代码

## Out of Scope (explicit)

* 新增其他群聊列表个性化选项（显示密度、agent badge 样式等）
* 修改 GroupChatListView 的布局/样式（只传参数，不重构组件）
* 实现动画/过渡效果
* 群聊过滤功能
* 保留旧的 session-specific 设置以兼容老版本

## Technical Notes

* 关键文件：
  - `apps/archipelago-macos/Sources/ArchipelagoApp/Views/AppearanceSettingsPane.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/AppModelTypes.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/Views/IslandPanelView.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/ArchipelagoServer/GroupChatListView.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/Views/V6NotchContent.swift`

* 设计系统：`ArchipelagoDesign` / `V6Palette`
