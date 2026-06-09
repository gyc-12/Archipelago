# Database Guidelines

> Database patterns and conventions for this project.

---

## Overview

<!--
Document your project's database conventions here.

Questions to answer:
- What ORM/query library do you use?
- How are migrations managed?
- What are the naming conventions for tables/columns?
- How do you handle transactions?
-->

(To be filled by the team)

---

## Query Patterns

<!-- How should queries be written? Batch operations? -->

(To be filled by the team)

---

## Migrations

<!-- How to create and run migrations -->

(To be filled by the team)

## Scenario: Archipelago Server-Backed Island Group CRUD Sync

### 1. Scope / Trigger

- Trigger: Island and embedded Archipelago Server both need to create, delete, and display the same group chats and group agents.
- Applies to Archipelago Server `src-tauri` database entities, migrations, group commands, HTTP handlers, event bridge, and Island Swift sync clients.
- Archipelago Server is the source of truth for Island-created group metadata. Island stores and renders a projection loaded from Archipelago Server.

### 2. Signatures

- Database tables:
  - `group_chat(id, name, folder_id, folder_path, primary_agent_id, created_at, updated_at, deleted_at)`
  - `group_agent(id, group_id, agent_type, role, conversation_id, connection_id, working_dir, created_at, updated_at, deleted_at)`
- HTTP endpoints:
  - `GET /groups`
  - `POST /groups/create`
  - `POST /groups/update`
  - `POST /groups/delete`
  - `POST /groups/agents/add`
  - `POST /groups/agents/update`
  - `POST /groups/agents/remove`
- WebSocket event names:
  - `island://group-upserted`
  - `island://group-deleted`
  - `island://agent-upserted`
  - `island://agent-deleted`

### 3. Contracts

- `GroupChatWithAgents` responses use camelCase and always return:
  - `group: GroupChatInfo`
  - `agents: GroupAgentInfo[]`
- `GroupChatInfo.id` is the stable Island group id. Do not generate a separate Island-only id for Archipelago Server-backed groups.
- `GroupAgentInfo.id` is the stable Island agent id.
- `group_chat.folder_id` binds a visible Island group to a Archipelago Server workspace folder.
- `group_agent.conversation_id` binds one Island agent membership to a Archipelago Server conversation.
- `group_agent.connection_id` is optional runtime state and may be absent when no ACP session is active.
- `group_agent.role` stores the user-assigned Island role for that group member. Archipelago Server-created group-agent rows default blank or omitted roles to `Coder`.
- Deletion is soft deletion by `deleted_at`; list APIs only return rows where `deleted_at IS NULL`.
- Adding a group agent is idempotent for the same `(group_id, agent_type)` while the row is active. It updates role, conversation, connection, working directory, and `updated_at` instead of creating duplicate visible members.
- Archipelago Server `create_conversation` and `delete_conversation` must maintain matching `group_agent` rows when the conversation is associated with an Island group.
- `group_chat.primary_agent_id` is editable after group creation through `update_group`.
- Island's group detail primary-agent star must call the existing `update_group(id, primaryAgentId)` path; do not add a separate primary-agent endpoint.
- After a primary-agent update, Island must reload/apply the Archipelago Server group projection so both the group list and detail view agree on the new default Archipelago Server conversation.

### 4. Validation & Error Matrix

- `update_group` for a missing or soft-deleted group -> return an application error; do not recreate implicitly.
- `update_group.primary_agent_id` must reference an active agent in the same group; callers should only pass ids from the current `GroupChatWithAgents.agents` set.
- `update_group_agent` for a missing or soft-deleted agent -> return an application error; do not recreate implicitly.
- `delete_group` for an already deleted group -> no-op success; emit the deletion event for caller sync.
- `remove_group_agent` for an already deleted agent -> no-op success; emit the deletion event for caller sync.
- Archipelago Server folder removal with matching groups -> soft-delete all active groups for that folder and emit `island://group-deleted`.
- Unknown/out-of-order sync event on Island -> reload `GET /groups` instead of trusting partial payload state.
- Duplicate visible agent rows for the same group and agent type -> incorrect; fix by preserving `add_agent` idempotency.

### 5. Good/Base/Bad Cases

- Good: Island creates a group with selected agents; Archipelago Server persists one `group_chat`, one `group_agent` per selected agent, creates conversations, emits upsert events, and both UIs show the same membership without refresh.
- Good: Archipelago Server deletes a workspace folder; Archipelago Server soft-deletes matching groups, emits deletion events, and Island removes them immediately.
- Good: Archipelago Server deletes an agent conversation associated with an Island group; the matching `group_agent` is soft-deleted and Island updates immediately.
- Good: Island changes the primary agent from the group detail star control; Archipelago Server persists `group_chat.primary_agent_id`, emits/returns the updated group projection, and later default group opening targets the newly selected agent conversation.
- Base: Island receives only a deletion event with ids; it refreshes `GET /groups` to rebuild the projection.
- Bad: Island creates a group named `11` in folder `trellis_try` and Archipelago Server shows both `11-*` and `trellis_try-*` conversation groups. The Archipelago Server workspace view must use the folder-bound conversation set, not a second name-prefixed synthetic set.
- Bad: historical Archipelago Server conversations are automatically imported into Island without an explicit user action.

### 6. Tests Required

- Run `cargo test --lib conversation_group_agent_sync_roundtrip --no-default-features` after changing Archipelago Server conversation/group-agent bridge behavior.
- Run `cargo build --release --bin archipelago-server --no-default-features` before packaging manual-test builds.
- Run `npm run build` after changing Archipelago Server frontend event listeners or workspace context.
- Run `swift test --filter ArchipelagoGroupChatTests` after changing Island group CRUD sync.
- Run `swift build --product ArchipelagoApp` before packaged app manual verification.
- Run `git diff --check`.
- Launch the packaged app with `zsh scripts/launch-packaged-app.sh` before asking for manual integrated testing.
- Manually verify that switching the primary-agent star in Island group detail updates the group list primary marker and the default Archipelago Server conversation opened from the group.

### 7. Wrong vs Correct

#### Wrong

```rust
// Creates another visible agent row when the same agent type is added again.
group_agent::ActiveModel {
    group_id: Set(group_id),
    agent_type: Set(agent_type),
    // ...
}.insert(conn).await?;
```

#### Correct

```rust
// Keep one active membership per group and agent type.
if let Some(existing) = find_active_agent(group_id, &agent_type).await? {
    update_existing_membership(existing).await?;
} else {
    insert_new_membership().await?;
}
```

#### Wrong

```swift
// Adds a separate primary-agent API and risks drifting from Archipelago Server's group projection.
try await client.setPrimaryAgent(groupId: groupId, agentId: agentId)
```

#### Correct

```swift
// Reuse the existing group update contract and apply the returned projection.
let response = try await client.updateGroup(id: groupDbId, primaryAgentId: agentDbId)
applyServerGroup(response)
```

---

## Scenario: Island Group Collaboration Prompt Enrichment

### 1. Scope / Trigger

- Trigger: a user sends a prompt from the Archipelago Server conversation bound to an Island group chat's primary agent and either mentions group agents with `@agent` / `@all` or Island explicitly requests automatic group collaboration.
- Applies to Archipelago Server ACP prompt commands, embedded HTTP prompt handlers, `group_chat` / `group_agent` lookups, and the existing `delegate_to_agent` MCP delegation runtime.
- The MVP uses prompt enrichment. It does not introduce a new scheduler, database table, or custom child-conversation persistence path.

### 2. Signatures

- Shared enrichment entry point:
  ```rust
  enrich_group_collaboration_prompt(
      db: &AppDatabase,
      blocks: Vec<PromptInputBlock>,
      conversation_id: Option<i32>,
  ) -> Result<Vec<PromptInputBlock>, AcpError>
  ```
- Shared enrichment entry point with explicit mode:
  ```rust
  enrich_group_collaboration_prompt_with_mode(
      db: &AppDatabase,
      blocks: Vec<PromptInputBlock>,
      conversation_id: Option<i32>,
      mode: GroupCollaborationMode,
  ) -> Result<Vec<PromptInputBlock>, AcpError>
  ```
- Shared analysis entry point for callers that need both prompt blocks and UI state:
  ```rust
  analyze_group_collaboration_prompt(
      db: &AppDatabase,
      blocks: Vec<PromptInputBlock>,
      conversation_id: Option<i32>,
  ) -> Result<GroupCollaborationEnrichment, AcpError>
  ```
- Shared analysis entry point with explicit mode:
  ```rust
  analyze_group_collaboration_prompt_with_mode(
      db: &AppDatabase,
      blocks: Vec<PromptInputBlock>,
      conversation_id: Option<i32>,
      mode: GroupCollaborationMode,
  ) -> Result<GroupCollaborationEnrichment, AcpError>
  ```
- Collaboration mode enum:
  ```rust
  #[serde(rename_all = "snake_case")]
  enum GroupCollaborationMode {
      Mention,
      Auto,
  }
  ```
- Event emitted before `send_prompt_linked` when a recognized Island group collaboration mention is resolved:
  ```rust
  AcpEvent::GroupCollaborationPlan {
      group_id,
      group_name,
      primary_agent_id,
      requested_mentions,
      invalid_mentions,
      members,
  }
  ```
- Prompt API callers that must invoke the enrichment before `send_prompt_linked`:
  - Tauri command `acp_prompt(connection_id, blocks, folder_id, conversation_id, collaboration_mode, ...)`
  - Embedded HTTP handler `POST /acp_prompt` with JSON field `collaborationMode`.
- Database bindings used:
  - `group_chat.primary_agent_id`
  - `group_agent.group_id`
  - `group_agent.agent_type`
  - `group_agent.conversation_id`
  - `group_agent.working_dir`
  - `group_agent.deleted_at`

### 3. Contracts

- Enrichment only runs when `conversation_id` is present and the prompt contains a recognized mention in `mention` mode or `collaborationMode == "auto"` is provided.
- `mention` is the default for all callers that omit the field. This preserves normal Archipelago Server chat behavior: no `@agent` / `@all` mention means no group collaboration enrichment.
- `auto` is the Island group-task mode. If the prompt has no explicit mentions, it behaves as `@all` and targets all active non-primary group agents. If the prompt includes explicit mentions, it honors those mentions instead of expanding to every member.
- HTTP/TypeScript/Swift payloads use camelCase `collaborationMode`; Rust internals use snake_case `collaboration_mode`; enum values on the wire are `mention` and `auto`.
- The conversation must resolve to an active `group_agent`.
- The resolved `group_agent.id` must equal its group's `primary_agent_id`; non-primary group agent conversations must not be enriched.
- Recognized mentions are normalized aliases for persisted `AgentType` values, for example `@codex`, `@gemini`, `@claude`, `@claude_code`, `@open_code`, and `@opencode`.
- `@all` expands to all active group agents except the primary agent.
- Mentioned agents that are not active members of the group are ignored.
- Mentioned agents that are recognized but not active members of the group are included in `invalid_mentions` for UI visibility.
- The enrichment appends one `PromptInputBlock::Text` containing a `<archipelago_group_collaboration>` instruction block.
- The instruction block must tell the primary agent to call the existing `delegate_to_agent` tool once per requested member, in mention order, and then produce one integrated final answer.
- The instruction block must tolerate host-specific MCP tool display names. It should name `delegate_to_agent` and mention visible equivalents such as `mcp__archipelago-delegate__delegate_to_agent` or `archipelago-delegate/delegate_to_agent`, because different ACP hosts expose the same MCP tool under different prefixes.
- Archipelago product settings must default `delegation.enabled` to true so a fresh or renamed Archipelago Server data directory still injects the built-in `archipelago-delegate` MCP server into primary-agent ACP sessions. `DelegationBroker::default()` may remain disabled as a low-level uninitialized/explicit kill-switch state, but app startup must apply persisted/default delegation settings before creating user ACP sessions.
- In `auto` mode, the instruction block must also tell the primary agent to understand the Island-submitted requirement, decompose it by member role, briefly expose the decomposition in the chat stream, delegate focused subtasks, wait for results, and aggregate the final answer.
- `GroupCollaborationPlan` is a live UI cue. It should not mutate `SessionState` snapshot content and should not be persisted as a conversation turn.
- `GroupCollaborationPlan.members[*].agent_id` is the stable `group_agent.id` used by Island to mark the matching group members busy.
- Tauri and embedded HTTP prompt paths must both emit the plan before sending the prompt so Archipelago Server web and Island WebSocket subscribers see the same collaboration lifecycle.

### 4. Validation & Error Matrix

- `conversation_id == None` -> return original blocks unchanged.
- `collaborationMode == "mention"` and no recognized mention -> return original blocks unchanged without querying group membership.
- `collaborationMode == "auto"` and no recognized mention -> treat as `@all` for active non-primary members.
- `collaborationMode == "auto"` with explicit recognized mentions -> resolve only those mentions.
- Conversation is not attached to any active `group_agent` -> return original blocks unchanged.
- Conversation is attached to a non-primary group agent -> return original blocks unchanged.
- Mentioned agent is not in the group -> ignore that mention.
- Mentioned agent is recognized but not in the group -> include it in `invalid_mentions`.
- All requested mentions resolve to no members -> return original blocks unchanged but still emit a plan with empty `members` and skipped/invalid mention data.
- Database lookup error -> surface `AcpError::protocol` so the caller reports a normal prompt-send failure.

### 5. Good/Base/Bad Cases

- Good: in a primary Claude Code group conversation, user sends `@codex @gemini review this plan`; Archipelago Server appends the collaboration context and Claude Code delegates to Codex and Gemini through `delegate_to_agent`.
- Good: Island sends `collaborationMode: "auto"` with `Create an implementation plan`; Archipelago Server enriches the primary-agent prompt with all active non-primary group members without requiring user-visible `@all` text.
- Good: user sends `@codex @open_code` in a group without OpenCode; Archipelago Server shows a live plan for Codex and a skipped `@open_code` row.
- Good: user sends `@all draft the next step`; Archipelago Server delegates to every active non-primary group member.
- Base: user sends `@codex` in a normal non-Island Archipelago Server conversation; no enrichment happens.
- Base: user sends `@codex` from the Codex member's own group conversation; no enrichment happens because only the primary agent orchestrates.
- Bad: Archipelago Server creates a separate orchestration scheduler that bypasses existing `delegate_to_agent` lifecycle events and breaks delegated sub-thread UI.
- Bad: Island group collaboration changes `group_agent.conversation_id` to point at transient delegation child conversations.

### 6. Tests Required

- Unit test mention parsing order and de-duplication.
- Unit test `@all` expansion excludes the primary agent and preserves group-agent order.
- Async unit test primary group conversation enrichment includes requested agent types and excludes the primary agent.
- Async unit test `auto` mode with no explicit mentions expands to all active non-primary group agents and records `requested_mentions == ["all"]`.
- Async unit test `auto` mode with explicit mentions honors those mentions and does not expand to all members.
- Async unit test plan output includes valid `members` with `agent_id` and recognized invalid mentions in `invalid_mentions`.
- Async unit test non-primary group agent prompt is not enriched.
- Async/unit test delegation settings load defaults to `enabled == true` when persistence has no explicit `delegation.enabled` row.
- Run `cargo test --lib group_collaboration --no-default-features`.
- Run `cargo test --lib commands::delegation --no-default-features` after changing delegation settings defaults.
- Run `cargo build --release --bin archipelago-server --no-default-features` before packaged manual testing.

### 7. Wrong vs Correct

#### Wrong

```rust
// Bypasses the existing delegation runtime and creates a parallel scheduler.
for member in mentioned_members {
    spawn_agent_and_poll_until_done(member).await?;
}
```

#### Correct

```rust
// Enrich the primary agent's prompt so the existing delegate_to_agent
// MCP lifecycle, broker, and frontend delegated-sub-thread UI stay in use.
let blocks = enrich_group_collaboration_prompt_with_mode(
    db,
    blocks,
    conversation_id,
    GroupCollaborationMode::Auto,
)
.await?;
manager
    .send_prompt_linked(db, connection_id, blocks, folder_id, conversation_id, None)
    .await?;
```

#### Wrong

```rust
// Only enriches the prompt; UI subscribers cannot show who will be delegated.
let blocks = enrich_group_collaboration_prompt(db, blocks, conversation_id).await?;
manager.send_prompt_linked(db, connection_id, blocks, folder_id, conversation_id, None).await?;
```

#### Correct

```rust
// Analyze once, emit the visible plan, then send the enriched prompt.
let enrichment = analyze_group_collaboration_prompt_with_mode(
    db,
    blocks,
    conversation_id,
    collaboration_mode.unwrap_or_default(),
)
.await?;
if let Some(plan) = enrichment.plan {
    manager.emit_group_collaboration_plan(connection_id, plan).await?;
}
manager
    .send_prompt_linked(db, connection_id, enrichment.blocks, folder_id, conversation_id, None)
    .await?;
```

---

## Naming Conventions

<!-- Table names, column names, index names -->

(To be filled by the team)

---

## Common Mistakes

<!-- Database-related mistakes your team has made -->

(To be filled by the team)
