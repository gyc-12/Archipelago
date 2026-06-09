# Archipelago 产品设计文档

## 1. 产品定位

Archipelago 是一个 macOS 桌面端多 Agent 协作应用。它把“群聊式 Agent 调度”放进桌面 Island 入口：用户可以从一个常驻、轻量的桌面浮层创建项目群聊、选择多个编码 Agent、指定主 Agent，并在需要时打开完整的嵌入式协作运行时查看对话、产物和设置。

产品目标不是再做一个独立聊天网页，而是把 AI 编码协作变成桌面工作流的一部分：

- Island 负责快速查看、创建、调度和状态反馈。
- 嵌入式 Archipelago Server 负责完整 IM、Agent 对话、文件工作区、产物预览和配置。
- 多 Agent 协作通过主 Agent + 成员 Agent 的群聊模型呈现，降低用户手动切换 CLI/窗口/上下文的成本。

## 2. 目标用户

| 用户 | 需求 | Archipelago 的回答 |
| :--- | :--- | :--- |
| 独立开发者 | 同时使用 Claude Code、Codex、Gemini、OpenCode 等工具完成项目任务 | 在同一个群聊中创建多个 Agent 成员，并让主 Agent 组织协作 |
| 前端/全栈工程师 | 希望边聊边看 HTML、Markdown、PPT、Diff、文件变更 | 消息里直接出现产物预览卡片，点击进入共享文件工作区 |
| 需要答辩/演示的开发者 | 需要证明 AI 协作过程可追溯，而不是只展示最终代码 | Trellis 记录 PRD、Spec、Skill、journal、验证和提交 |
| macOS 重度用户 | 希望 AI 工具像系统能力一样常驻、轻量、原生 | Island UI + SwiftUI 外壳 + macOS 风格 Web runtime |

## 3. 核心场景

### 3.1 创建多 Agent 群聊

用户从 Island 展开面板点击新建群聊，选择本地 workspace，勾选 Agent，并设置主 Agent。系统在 Archipelago Server 中创建 group_chat/group_agent 数据，并为每个成员绑定 conversation。

用户价值：

- 不需要手动在多个工具中打开同一项目。
- 每个 Agent 的角色、工作目录、会话绑定都成为群聊的一部分。
- 群聊结构由运行时持久化，Island 只展示投影，避免双写漂移。

### 3.2 IM 核心聊天体验

用户打开群聊后进入嵌入式 Archipelago Server 会话窗口。聊天体验包括：

- 对话列表、会话详情、消息流和输入框。
- Agent 选择和会话配置。
- 文件引用、图片附件、本地文件附加。
- 权限请求、思考强度、模式选择等输入栏控制。
- macOS 风格图标、设置页、状态栏和消息气泡。

设计原则：

- 聊天是工作界面，不做营销式首屏。
- 工具按钮使用图标表达，候选项用语义图标增强扫描效率。
- Agent 身份图标保留提供商语义，系统操作图标走 Apple-style 视觉。

### 3.3 多 Agent 调度

群聊中的主 Agent 是默认 orchestrator。用户可以在群聊中使用 `@agent` / `@all`，或从 Island 发送 group task，让主 Agent 自动规划并委派成员 Agent。

协作反馈包括：

- `group_collaboration_plan` 事件显示本轮计划。
- 被委派成员进入 busy 状态。
- 子 Agent 完成后回写 summary。
- 主 Agent 完成后，Island 展示最终摘要并恢复成员状态。

这让多 Agent 调度不是后台黑盒，而是可见、可解释、可追踪的群聊状态。

### 3.4 产物预览与编辑

Agent 回复中如果引用或生成文件，消息内直接出现产物预览卡片。卡片是薄入口，真正打开、编辑、Diff、保存、历史等逻辑复用 WorkspaceContext 和文件工作区。

已覆盖的产物类型：

- HTML/Web：iframe 预览或源码 fallback。
- Markdown/文档：渲染预览。
- 图片：缩略图与图片预览。
- PPTX：真实 PPT 浏览，提取 slide 文本与图片。
- Diff：打开统一 diff 视图。
- 代码/文本文件：进入 Monaco 编辑器。
- 版本历史：在全屏预览中查看可用历史信息。
- 对话式局部修改：选择代码/内容后，把修改上下文送回聊天输入。

用户价值：

- 不离开聊天上下文即可验证生成结果。
- 预览和编辑不重复造状态模型，避免保存、脏状态、冲突处理分裂。
- 产物从“文字描述”变成“可点、可看、可改”的工作对象。

## 4. 主要信息架构

```text
Archipelago.app
├── Island
│   ├── 折叠态：运行状态、群聊数量、动态指示
│   └── 展开态
│       ├── 我的群聊
│       ├── 群聊详情
│       ├── 新建群聊
│       └── 外观/运行时入口
└── Embedded Archipelago Server
    ├── Workspace
    ├── Conversation
    ├── File workspace / preview / diff / editor
    ├── Settings
    └── Web service
```

## 5. 关键用户流程

### 流程 A：创建群聊并开始协作

1. 展开 Island。
2. 点击新建群聊。
3. 选择 workspace 文件夹。
4. 选择 Claude Code、Codex、Gemini CLI、OpenCode 等 Agent。
5. 设置主 Agent。
6. 提交后进入群聊列表。
7. 双击群聊打开嵌入式会话窗口。
8. 在输入框发送任务，必要时使用 `@all` 或具体 Agent。

### 流程 B：查看 Agent 完成状态

1. Agent 回复时，Island 折叠态显示运行状态。
2. 群聊列表展示 Agent badge 和工作状态。
3. Agent 完成后，Island 打开/聚焦对应群聊详情。
4. 群聊详情展示最新回复摘要。

### 流程 C：查看和编辑产物

1. Agent 在消息中生成或引用 HTML、Markdown、PPT、代码文件或 Diff。
2. 消息内出现预览卡片。
3. 点击卡片进入文件工作区或全屏预览。
4. 查看 iframe/PPT/Markdown/Diff。
5. 选择代码片段并在聊天中描述局部修改。
6. Agent 基于选中上下文继续修改。

## 6. 体验与视觉策略

### 6.1 macOS 原生感

Swift Island 与 Web runtime 统一使用 Apple/macOS 风格：

- 系统字体栈与紧凑信息层级。
- 克制的卡片、边框、状态色。
- 工具栏图标使用 Apple-style 语义组件。
- 设置页与运行时控制减少通用 Web 工具感。

### 6.2 Provider 身份保留

Claude、Codex、Gemini、OpenCode 等 Agent 图标保留各自身份语义，不被统一替换成系统图标。这样用户在多 Agent 群聊中能快速识别“谁在工作、谁完成了、谁被委派”。

### 6.3 工作流优先

应用首屏不是 landing page，而是可用工作台：

- Island 展开即是群聊列表和操作入口。
- 会话窗口直接进入聊天与文件工作区。
- 产物预览直接出现在消息流里。

## 7. MVP 与扩展边界

| 层级 | 已落地能力 | 后续可扩展 |
| :--- | :--- | :--- |
| P0 | 群聊创建、Agent 选择、主 Agent、IM 聊天、状态同步 | 更细角色模板、群聊导入 |
| P1 | 多 Agent mention/auto 调度、委派状态投影、最新摘要 | 可视化任务 DAG、调度策略配置 |
| P1 | 文件/HTML/Markdown/图片/Diff/PPT 预览 | 更完整的文档编辑和安全沙箱 |
| P1 | 对话式局部修改 | 多选上下文、批量变更计划 |
| P2 | Web service LAN 访问 | 团队共享、远程控制 |

## 8. 创新点

- 桌面 Island 作为多 Agent 协作入口，降低 AI 工具切换成本。
- 群聊模型把 Agent 成员、角色、会话、工作目录和主 Agent 统一成可持久化对象。
- 多 Agent 调度通过 IM 事件可视化，而不是隐藏在后台日志里。
- 产物预览卡片把生成结果从静态文本升级为可检查、可编辑、可继续对话的对象。
- Trellis 把 AI 协作过程本身产品化为 spec、skill、rules、journal 和任务档案。

