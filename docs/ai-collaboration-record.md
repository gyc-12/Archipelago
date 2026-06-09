# AI 协作开发记录

## 1. 协作方法概览

本项目使用 Trellis 管理 AI 协作开发。核心目标是把 AI 开发从“临时对话”升级为可追溯、可复用、可审查的工程流程。

Trellis 在本项目中承担四类资产：

- Workflow：规定 plan、execute、finish 的开发阶段。
- Spec：沉淀前端、后端、跨层数据流、错误处理、质量门禁等项目规范。
- Skill：把 start、before-dev、brainstorm、check、finish-work 等流程封装成可复用能力。
- Journal/Task：记录每次开发 session、PRD、实现上下文、验证和归档。

迁移后的原始材料位于 [trellis/](./trellis/)。

## 2. Trellis 规则与流程

Trellis workflow 的核心原则：

1. Plan before code：写代码前先明确目标和边界。
2. Specs injected, not remembered：规范通过文件/skill 注入，而不是依赖模型记忆。
3. Persist everything：PRD、决策、验证、复盘都进入文件。
4. Incremental development：一次完成一个任务。
5. Capture learnings：修复和踩坑沉淀回 spec。

实际开发阶段：

| 阶段 | 动作 | 产物 |
| :--- | :--- | :--- |
| Phase 1 Plan | 创建 task、brainstorm、PRD、上下文配置 | `.trellis/tasks/*/prd.md`、`implement.jsonl`、`check.jsonl` |
| Phase 2 Execute | 读取 spec、实现、测试、修复 | 代码提交、测试结果 |
| Phase 3 Finish | 质量验证、spec 更新、commit、归档、journal | `.trellis/tasks/archive/*`、`.trellis/workspace/gyc/journal-1.md` |

## 3. Spec 沉淀示例

### 3.1 前端组件规范

`docs/trellis/spec/frontend/component-guidelines.md` 沉淀了以下可执行约束：

- Archipelago Server 的用户界面操作图标使用 `AppleIcon` / `AppleIconTile`。
- Provider 身份图标继续使用 `AgentIcon`。
- Island SwiftUI 中使用 `ArchipelagoAgentIconView`，保持与 Web runtime 一致。
- 产物预览卡片必须启动共享 WorkspaceContext，不维护第二套文件编辑状态。
- Agent chip 必须固定图标尺寸、限制宽度、文本截断，防止输入栏溢出。

### 3.2 前端状态规范

`docs/trellis/spec/frontend/state-management.md` 沉淀了跨端状态契约：

- Island group chat 生命周期由 Archipelago Server 事件驱动。
- WebSocket `turn_complete` 丢失时，HTTP snapshot fallback 也要触发完成路径。
- collapsed Island 状态由 AppModel 持有投影，不让 View 直接读取嵌套 coordinator。
- `group_collaboration_plan` 是 live UI signal，不是持久化 conversation turn。
- 委派子 Agent 必须基于真实子结果恢复状态，不能只靠 generic completed fallback。

### 3.3 后端数据库规范

`docs/trellis/spec/backend/database-guidelines.md` 沉淀了 group CRUD 和同步契约：

- `group_chat` / `group_agent` 表结构。
- group 和 agent 的 HTTP API。
- `island://group-upserted` 等 WS 事件。
- `deleted_at` 软删除。
- 同一 group 内同一 agent_type 幂等添加。
- primary agent 更新复用 `update_group`，不新增漂移 endpoint。

### 3.4 错误处理规范

`docs/trellis/spec/backend/error-handling.md` 沉淀了真实集成问题的处理：

- 集成手测必须使用 `zsh scripts/launch-packaged-app.sh`。
- packaged smoke 未通过时不打开 app。
- 嵌入式 Web Service 对外绑定与内部 loopback URL 分离。
- MCP marketplace 403 用只读 curl fallback，不扩散到写操作。

## 4. Skill 体系

迁移后的 skill 位于 [trellis/skills/](./trellis/skills/)。

| Skill | 用途 |
| :--- | :--- |
| `trellis-start` | 初始化开发会话，读取 workflow、身份、git、任务和规范。 |
| `trellis-before-dev` | 开发前读取适用 spec 和 thinking guide。 |
| `trellis-brainstorm` | 需求探索、创建 PRD、收敛 MVP 范围。 |
| `trellis-check` | 质量验证：spec compliance、lint、type-check、tests、跨层检查。 |
| `trellis-update-spec` | 将新规则、新错误模式和架构决策写回 spec。 |
| `trellis-break-loop` | 修复重复问题后分析根因，避免 fix-forget-repeat。 |
| `trellis-finish-work` | 完成会话、归档任务、记录 journal。 |

## 5. 开发里程碑摘要

| 时间 | 任务 | 结果 |
| :--- | :--- | :--- |
| 2026-05-25 | Island  Phase 1 | 建立群聊创建、Agent 添加、状态概览、跳转运行时的端到端基础。 |
| 2026-06-03 | Runtime event source | 从 CLI hook 切到运行时 HTTP/WS，Island 展示真实 Agent 生命周期和摘要。 |
| 2026-06-04 | CRUD Sync | Archipelago Server 成为 group metadata source of truth，Island 做投影同步。 |
| 2026-06-04 | Group orchestrator collaboration | 支持 `@agent` / `@all`、协作计划事件、主 Agent 切换。 |
| 2026-06-05 | Island group task delegation | 支持 Island 发送 group task、auto collaboration、委派 Agent 状态和 summary 同步。 |
| 2026-06-07 | UI 个性化与原生风格 | 设置预览、排序、右槽状态、macOS 风格 runtime UI、Apple-style 图标。 |
| 2026-06-08 | Artifact preview and editing | 落地 inline artifact card、HTML/PPT/Diff/History/局部修改。 |
| 2026-06-08 | Runtime controls polish | 修复 Finder reveal、本地文件选择、图标风格和底栏候选项图标。 |

完整 session journal 见 [trellis/workspace/journal-1.md](./trellis/workspace/journal-1.md)。

## 6. AI 协作如何提升质量

### 6.1 减少需求漂移

每个较大任务先写 PRD，并把 scope、out-of-scope、acceptance criteria 写清楚。例如 artifact preview 的 PRD 明确“先不做完整安全策略，快速落地所有功能”，避免实现阶段在安全沙箱上过度发散。

### 6.2 让跨层契约可检查

Swift、React、Rust、SQLite 同时改动时，Trellis spec 记录了跨层数据流：

- HTTP 字段使用 camelCase。
- Rust 内部使用 snake_case。
- WS 事件名称稳定。
- Island 未知事件必须重拉 server projection。

这让后续 AI 修改可以先读契约，不依赖旧对话上下文。

### 6.3 把 bug 变成规则

若出现 UI 点击无效、文件选择无响应、状态投影不刷新等问题，修复后会写入 spec 或 journal：

- 本地文件附加需要 `WKUIDelegate runOpenPanelWith`。
- Finder reveal 需要 runtime server command 支持。
- collapsed Island 状态不能依赖嵌套对象间接刷新。
- artifact card 不能自建独立编辑状态。

### 6.4 保持可运行 Demo

用户多次要求“重启 app”，项目规范最终沉淀为：涉及前端/Swift/运行时代码修改后，先重新构建前端和 helper，再 package + launch packaged app。这样演示路径使用真实 `.app` bundle，而不是开发进程。

## 7. 质量门禁记录

根据不同任务运行过的验证包括：

- `pnpm build`
- `pnpm exec vitest run`
- `cargo build --release --bin archipelago-server --bin archipelago-mcp --no-default-features`
- `cargo test --lib ... --no-default-features`
- `swift test --filter ArchipelagoGroupChatTests`
- `swift build --product ArchipelagoApp`
- `zsh scripts/launch-packaged-app.sh`
- `git diff --check`

本次文档整理只修改 `docs/`，未改运行代码，因此不需要重新打包或重启 app。

## 8. 可审计证据

- 原始工作流：[trellis/workflow.md](./trellis/workflow.md)
- 原始规范：[trellis/spec/](./trellis/spec/)
- 原始 skills：[trellis/skills/](./trellis/skills/)
- 仓库规则：[trellis/rules/AGENTS.md](./trellis/rules/AGENTS.md)
- Session journal：[trellis/workspace/journal-1.md](./trellis/workspace/journal-1.md)

