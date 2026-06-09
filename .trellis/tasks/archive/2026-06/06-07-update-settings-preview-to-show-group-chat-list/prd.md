# 更新设置界面：会话列表改为群聊列表预览

## Goal

将 macOS 设置界面（Appearance Settings）中的"会话列表预览"部分改为"群聊列表预览"，使预览内容与当前 app 的群聊列表（GroupChatListView）样式一致。

## What I already know

* **当前实现**：
  - 文件：`apps/archipelago-macos/Sources/ArchipelagoApp/Views/AppearanceSettingsPane.swift`
  - 当前预览：`SessionListPanelPreview` (line 890-1124) 显示 agent 会话列表
  - 预览数据：`previewSessionItems` (line 715-798) 包含模拟的会话数据
  - 本地化字符串：`zh-Hans.lproj/Localizable.strings` line 59, 100 等提到"会话列表"

* **目标样式参考**：
  - 文件：`apps/archipelago-macos/Sources/ArchipelagoApp/ArchipelagoServer/GroupChatListView.swift`
  - 组件：`GroupChatListView` + `GroupChatRow` (line 3-157)
  - 布局：
    - Header: "我的群聊" + 创建按钮 + 群聊数量
    - List: 每行显示群聊名称、workspace、agent badges、状态点
    - 样式：圆角卡片 (radiusSm)、边框、elevated 背景色

* **技术约束**：
  - 使用 SwiftUI
  - 遵循 ArchipelagoDesign 设计系统
  - 支持多语言（中文/英文）
  - 预览数据需要模拟群聊结构（GroupChat 模型）

## Assumptions (temporary)

* 不需要实现真实的群聊数据绑定，只需静态预览
* 预览的交互功能（点击、悬停）可以省略
* 保持现有的 SettingsPreviewStage 容器和布局结构

## Requirements

1. **替换 SessionListPanelPreview**：
   - 新组件名：`GroupChatListPanelPreview`
   - 显示群聊列表预览而非会话列表
   
2. **匹配 GroupChatListView 样式**：
   - Header 布局：创建按钮 + "我的群聊" 标题 + 数量
   - List 项样式：圆角卡片、边框、agent badges、状态点
   - 间距、字体、颜色与 GroupChatListView 一致

3. **模拟数据**（✅ 用户确认：3个群聊）：
   - 群聊1：多个 agent，working 状态
   - 群聊2：单个 agent，idle 状态
   - 群聊3：2个 agent，blocked 状态

4. **本地化更新**：
   - 更新 `settings.appearance.sessionListPart.title` 为"群聊列表"
   - 更新预览相关文本
   
5. **复用现有组件**：
   - Agent badges 样式复用 GroupChatRow 的实现
   - 不显示空状态/加载状态（只展示正常列表）

## Acceptance Criteria

* [ ] AppearanceSettingsPane 中的预览部分显示群聊列表
* [ ] 预览样式与 GroupChatListView 一致（圆角卡片、badges、状态点）
* [ ] 模拟数据包含 3 个不同配置的群聊
* [ ] Header 显示"我的群聊"标题和群聊数量
* [ ] 中文本地化字符串已更新
* [ ] 英文本地化字符串已更新（如有）
* [ ] 预览在不同 display profile（notch/topBar）下正常显示

## Definition of Done (team quality bar)

* 代码编译通过
* 视觉样式与 GroupChatListView 一致
* 本地化字符串完整
* 预览在设置界面中正常渲染

## Out of Scope (explicit)

* 实现真实的群聊数据绑定
* 添加交互功能（点击、悬停效果）
* 修改 GroupChatListView 本身
* 修改其他设置页面

## Technical Notes

* 关键文件：
  - `apps/archipelago-macos/Sources/ArchipelagoApp/Views/AppearanceSettingsPane.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/ArchipelagoServer/GroupChatListView.swift`
  - `apps/archipelago-macos/Sources/ArchipelagoApp/Resources/zh-Hans.lproj/Localizable.strings`
  
* 设计系统参考：
  - `ArchipelagoDesign.rowTitleFont()`, `rowCaptionFont()`, `badgeFont()`
  - `ArchipelagoDesign.radiusSm`, `spacingSm`
  - `ArchipelagoDesign.onDarkPrimary`, `onDarkSecondary`, `onDarkTertiary`
  - `ArchipelagoDesign.onDarkSurfaceElevated`, `onDarkBorder`

* 数据模型：`GroupChat`, `GroupAgent`, `AgentDisplayStatus`
