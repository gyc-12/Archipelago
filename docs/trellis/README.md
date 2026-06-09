# Trellis 协作材料迁移说明

本目录从项目根目录迁移 Trellis 和 Agent 协作相关材料，作为“AI 协作能力”交付物的原始证据。

## 内容结构

| 路径 | 来源 | 说明 |
| :--- | :--- | :--- |
| [workflow.md](./workflow.md) | `.trellis/workflow.md` | Trellis 开发阶段、任务生命周期、上下文注入和完成流程。 |
| [spec/](./spec/) | `.trellis/spec/` | 前端、后端、跨层思考指南等项目级编码规范。 |
| [skills/](./skills/) | `.agents/skills/` | Trellis skills，包括 start、before-dev、brainstorm、check、finish-work 等。 |
| [rules/AGENTS.md](./rules/AGENTS.md) | `AGENTS.md` | 仓库级 AI Agent 工作规则和 Trellis 入口说明。 |
| [workspace/journal-1.md](./workspace/journal-1.md) | `.trellis/workspace/gyc/journal-1.md` | AI 开发 session journal，记录任务、提交、验证和复盘。 |

## 评审关注点

- `spec/frontend/component-guidelines.md`：沉淀了 Archipelago Server Apple-style 图标、AgentIcon 语义、产物预览卡片复用 WorkspaceContext 等规范。
- `spec/frontend/state-management.md`：沉淀了 Island group chat 生命周期、closed Island 状态投影、group collaboration plan 等跨 Swift/Web 状态契约。
- `spec/backend/database-guidelines.md`：沉淀了 group_chat/group_agent 表、HTTP API、WebSocket event、软删除和幂等规则。
- `spec/backend/error-handling.md`：沉淀了集成启动、嵌入式 Web Service、MCP marketplace fallback 等真实问题的处理矩阵。
- `workflow.md`：说明开发不是纯对话记忆，而是以 task、spec、journal、quality gate 作为可追溯协作资产。

## 说明

这些文件是当前项目 AI 协作规范的快照。面向评审的总结请看 [../ai-collaboration-record.md](../ai-collaboration-record.md)。

