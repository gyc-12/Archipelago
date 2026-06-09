# 群聊协作 Orchestrator 多 Agent 顺序回复

## Goal

在 Island 创建的群聊所对应的 Codeg 主 Agent 对话中，用户可以在一条消息里 `@` 多个 Agent。主 Agent 作为 Orchestrator 自动理解被点名成员、按成员角色拆分任务，并通过 Codeg 现有的 `delegate_to_agent` 委派链路依次获得各 Agent 产出，最后汇总回复。

## What I Already Know

- Island 群聊已经由 Codeg 的 `group_chat` / `group_agent` 持久化。
- `group_chat.primary_agent_id` 标识主 Agent。
- `group_agent.conversation_id` 绑定群聊成员对应的 Codeg conversation。
- Codeg 已经有成熟的 ACP delegation 链路：
  - agent 侧通过 MCP `delegate_to_agent` 工具发起子 Agent；
  - 后端通过 `DelegationBroker` 创建 child conversation；
  - 前端通过 `DelegatedSubThread` 展示子 Agent 产出。
- 当前 Codeg prompt 入口同时存在 Tauri command 和 embedded HTTP handler，二者都调用 `ConnectionManager::send_prompt_linked`。

## MVP Scope

- 仅对 Island 群聊的主 Agent conversation 生效。
- 支持在用户文本中识别 `@codex`、`@claude`、`@claude_code`、`@gemini`、`@open_code`、`@opencode`、`@all` 等成员 mention。
- 被 mention 的 Agent 必须是当前群聊中已存在的 active `group_agent`。
- 后端在发给主 Agent 的 prompt 前注入协作上下文，明确要求主 Agent：
  - 作为 Orchestrator；
  - 按 mention 顺序逐个调用 `delegate_to_agent`；
  - 传入成员的 `agent_type`、角色、工作目录和用户任务；
  - 收集各 Agent 结果后做最终汇总。
- Codeg 在发送 prompt 前发出 `group_collaboration_plan` 事件：
  - Codeg 对话页将计划渲染成 live plan，显示将要委派的成员；
  - 被识别但不是当前群聊 active 成员的 mention 显示为 skipped；
  - Island 收到该事件后，把被委派成员标记为忙碌并显示“协作已开始”摘要。
- Codeg 主 Agent 对话输入区显示当前群聊成员 chip 和 `@all` 快捷入口，点击后插入对应 mention。
- 普通 Codeg 单 Agent 对话、非主 Agent conversation、没有有效 mention 的消息不改变行为。

## Out Of Scope

- 不在第一版新增完整 @ autocomplete；只提供群聊成员快捷 chip。
- 不新增数据库表。
- 不强制模型一定按顺序调用工具；本阶段通过 prompt contract 约束 Orchestrator。
- 不把 delegation child conversation 强行改写成现有 `group_agent.conversation_id`。
- 不做复杂冲突处理、重试编排、并发/串行运行器。

## User Interaction

示例：

```text
@codex @gemini 分析这个项目下一阶段怎么做，codex 负责实现风险，gemini 负责产品视角。
```

预期：

- 用户仍然只在主 Agent 对话中发送一条消息。
- 主 Agent 自动调用 Codeg 的 delegation 工具。
- Codeg 输入区可通过群聊成员 chip 快速插入 `@codex`、`@gemini` 或 `@all`。
- Codeg 对话页在回复开始前展示协作计划，列出将委派的成员和被跳过的无效 mention。
- Island 群聊详情中对应成员实时显示忙碌；主 Agent 完成后恢复为空闲并写入最后回复摘要。
- Codeg 对话页中可以看到每个被委派 Agent 的产出卡片。
- 主 Agent 最后给出整合后的答复。

## Technical Notes

- 新增后端 prompt enrichment 模块，放在 Codeg ACP 层。
- `acp_prompt` Tauri command 和 HTTP handler 都需要走同一个 enrichment 函数。
- enrichment 需要先从 prompt text 中解析 mention；没有 mention 时不查询数据库。
- 数据流：

```text
Codeg UI send
  -> acp_prompt
  -> analyze_group_collaboration_prompt(db, blocks, conversation_id)
  -> emit group_collaboration_plan
  -> ConnectionManager::send_prompt_linked
  -> Orchestrator agent
  -> delegate_to_agent
  -> existing delegation broker / child conversations / inline UI
```

## Acceptance Criteria

- [x] Island 群聊主 Agent conversation 中发送 `@codex @gemini ...` 时，主 Agent 收到带有群聊成员上下文的 prompt。
- [x] 有效 mention 按用户书写顺序去重。
- [x] `@all` 展开为群聊中除主 Agent 外的所有成员。
- [x] 非群聊 conversation 不注入。
- [x] 群聊中的非主 Agent conversation 不注入。
- [x] 未 mention 当前群聊成员时不注入。
- [x] Tauri 和 embedded HTTP 两个 prompt 入口行为一致。
- [x] Codeg 对话页能显示协作计划 live plan，包含将委派成员和 skipped mention。
- [x] Codeg 主 Agent 输入区能展示群聊成员快捷 chip 和 `@all`。
- [x] Island 收到协作计划后能把被委派成员标记为忙碌。
- [x] 主 Agent 完成后，Island 能恢复本轮协作成员为空闲并写入最后摘要。
- [x] 补充 Rust 单元测试覆盖 mention 解析和注入判定。
- [x] 补充 Rust 单元测试覆盖 plan 输出中的有效成员和无效 mention。

## Definition Of Done

- Focused Rust tests 通过。
- `cargo build --release --bin codeg-server --no-default-features` 至少完成一次。
- `git diff --check` 通过。
- 如需人工验证，使用 `agentsIsland/open-vibe-island/scripts/launch-packaged-app.sh` 启动集成 app。
