# 重构 Archipelago 对话界面为 macOS 原生 SwiftUI 风格

## Goal

重构 `modules/collaboration-runtime` 的对话界面 UI，从当前的通用 Web 风格改为 macOS 原生 SwiftUI 风格，参考 `DESIGN.md` 中定义的 Apple 设计语言规范，让界面更贴合 macOS 用户体验。

## What I already know

* **当前技术栈**：
  - Next.js + React + TypeScript
  - Tailwind CSS + shadcn/ui 组件库
  - 使用 `lucide-react` 图标（User, Bot, Terminal, Cpu）
  - 当前主题系统：data-theme 属性 + CSS 变量（oklch 色彩空间）

* **主要组件结构**：
  - `src/components/message/message-bubble.tsx` — 消息气泡（38 行）
  - `src/components/conversations/conversation-detail-panel.tsx` — 对话详情面板
  - `src/components/conversations/sidebar-conversation-list.tsx` — 侧边栏对话列表（1544 行）
  - `src/components/conversations/sidebar-conversation-card.tsx` — 对话卡片（323 行）
  - `src/components/chat/message-input.tsx` — 消息输入框
  - `src/components/chat/agent-selector.tsx` — Agent 选择器

* **当前样式特征**：
  - 消息气泡：圆形头像 + 角色标签 + 时间戳
  - 用户消息：`bg-muted/30` 背景
  - 图标：lucide-react（通用图标库）
  - 间距：`gap-3`、`px-4 py-3`

* **DESIGN.md 设计规范**：
  - **颜色**：Action Blue (#0066cc / #0071e3)，墨水色 (#1d1d1f)，纯白画布
  - **字体**：SF Pro Display / SF Pro Text，负间距（-0.28px ~ -0.374px）
  - **风格**：极简主义，UI chrome 后退，产品优先，无装饰渐变，无阴影（仅产品图片有阴影）

## Assumptions (temporary)

* 需要将裸露的 lucide-react 图标封装为 SF Symbols 风格的彩色 Apple-style 图标组件
* 需要调整色彩方案以匹配 Apple 设计语言
* 需要使用 SF Pro / system font stack，不把 Apple 字体或 SF Symbols 字体作为 Web 资产打包
* 布局需要更宽松、更透气（macOS 风格 vs Web 紧凑风格）

## Open Questions

*（已解答所有关键问题）*

## Requirements

**✅ 用户确认：iMessage 风格 + SF Symbols 字体 + 完整暗色模式支持**

### 1. 消息气泡重设计（iMessage 风格）
- **用户消息**：Action Blue (#0066cc) 圆角气泡，右对齐
- **AI 消息**：灰色圆角气泡（surface-pearl #fafafc），左对齐
- **气泡样式**：
  - 更大的圆角（16px+）
  - 带有尾巴（tail）指向发送者
  - 内边距：16px-20px（比当前更宽松）
  - 最大宽度限制（避免过宽）
- **头像**：移除圆形头像，改为在气泡尾部显示小型 Agent 图标（保留提供商 logo）

### 2. 色彩系统重构
- **浅色模式**：
  - 背景：canvas (#ffffff) 或 canvas-parchment (#f5f5f7)
  - 主色调：Action Blue (#0066cc, hover: #0071e3)
  - 文本：ink (#1d1d1f)、ink-muted-48 (#7a7a7a)
  - 用户消息气泡：primary (#0066cc) + on-primary (#ffffff 文字)
  - AI 消息气泡：surface-pearl (#fafafc) + ink (#1d1d1f 文字)
  
- **暗色模式**：
  - 背景：surface-tile-1/2/3 (#272729 / #2a2a2c / #252527)
  - 主色调：primary-on-dark (#2997ff)
  - 文本：on-dark (#ffffff)、body-muted (#cccccc)
  - 用户消息气泡：primary-on-dark (#2997ff) + on-dark (#ffffff 文字)
  - AI 消息气泡：surface-tile-2 (#2a2a2c) + on-dark (#ffffff 文字)

### 3. 字体系统更新
- **字体族**：
  - 大标题：SF Pro Display
  - 正文/消息：SF Pro Text
  - 系统回退：`system-ui, -apple-system, sans-serif`
  
- **应用 DESIGN.md 规范**：
  - body (17px, 400, -0.374px letter-spacing, 1.47 line-height)
  - body-strong (17px, 600, -0.374px letter-spacing)
  - caption (14px, 400, -0.224px letter-spacing)
  - 时间戳/元信息使用 caption

### 4. UI 图标替换为 Apple-style 彩色图标组件
- **图标技术路线**：
  - 保留 `lucide-react` 作为可打包、可维护的底层 glyph source
  - 新增 `AppleIcon` / `AppleIconTile` 语义组件，将图标渲染成类似 SwiftUI / macOS 设置页的彩色圆角符号
  - 不直接打包 Apple SF Symbols 字体或 Apple 字体文件

- **替换场景**（保留 Agent 提供商 logo）：
  - 工具栏按钮图标
  - 状态指示器
  - 侧边栏操作图标
  - 输入框附加按钮

### 5. 布局优化
- **消息列表**：
  - 增加垂直间距（消息之间 12-16px）
  - 左右留白增加（24-32px）
  - 移除不必要的分割线
  
- **侧边栏对话卡片**：
  - 更大的圆角（12px+）
  - Hover 状态：surface-pearl 背景
  - 选中状态：Action Blue 左侧强调线 + 浅蓝背景
  
- **输入框**：
  - 更大的圆角
  - 更明显的边框（hairline #e0e0e0）
  - 内边距增加

### 6. 暗色模式适配
- 所有组件支持 `.dark` 类切换
- 使用 DESIGN.md 定义的暗色变量
- 保持与浅色模式一致的视觉层次

## Acceptance Criteria

* [ ] 消息气泡采用 iMessage 风格（圆角气泡 + 尾巴）
* [ ] 用户消息使用 Action Blue 背景，AI 消息使用灰色背景
* [ ] 消息左右对齐正确（用户右对齐，AI 左对齐）
* [ ] 字体使用 SF Pro Text/Display，应用正确的 letter-spacing
* [ ] 色彩系统匹配 DESIGN.md 规范（浅色 + 暗色模式）
* [ ] UI 图标（非 Agent logo）使用 Apple-style 彩色符号组件
* [ ] 布局更宽松，留白增加
* [ ] 暗色模式完全适配，所有组件正常显示
* [ ] 现有功能无退化（消息展示、输入、滚动、Agent 切换等）
* [ ] 在 macOS 桌面环境测试通过

## Definition of Done (team quality bar)

* 编译通过，无 TypeScript 错误
* 在桌面环境测试通过
* UI 变更不影响消息加载、发送等核心功能
* 代码风格一致

## Out of Scope (explicit)

* 不修改消息协议或数据结构
* 不重构 WebSocket 连接逻辑
* 不添加新功能（只改样式）
* 不迁移到其他 UI 框架（保持 React + Tailwind）

## Technical Notes

* 关键文件：
  - `modules/collaboration-runtime/src/components/message/message-bubble.tsx`
  - `modules/collaboration-runtime/src/components/message/message-list-view.tsx`
  - `modules/collaboration-runtime/src/components/ui/button.tsx`
  - `modules/collaboration-runtime/src/components/settings/settings-shell.tsx`
  - `modules/collaboration-runtime/src/components/conversations/*.tsx`
  - `modules/collaboration-runtime/src/app/globals.css`
  - `DESIGN.md` — 设计规范参考

* 技术约束：
  - 保持 Next.js + React 技术栈
  - 使用 Tailwind CSS（可扩展配置）
  - 不破坏现有组件 API
  - 不直接打包 Apple SF Symbols / Apple 字体资产；使用系统字体栈与自有组件模拟原生风格
