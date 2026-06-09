# State Management

> How state is managed in this project.

---

## Overview

<!--
Document your project's state management conventions here.

Questions to answer:
- What state management solution do you use?
- How is local vs global state decided?
- How do you handle server state?
- What are the patterns for derived state?
-->

(To be filled by the team)

---

## State Categories

<!-- Local state, global state, server state, URL state -->

(To be filled by the team)

---

## When to Use Global State

<!-- Criteria for promoting state to global -->

(To be filled by the team)

---

## Server State

### Scenario: Island Group Chat Lifecycle From Archipelago Server Events

#### 1. Scope / Trigger

- Trigger: Island needs to show lifecycle state for group chats created through Island and backed by embedded Archipelago Server.
- Applies to `ArchipelagoCoordinator`, `ArchipelagoClient`, local `GroupChat` storage, `GroupChatListView`, `GroupDetailView`, and the Island settings sync status.
- CLI hooks are not the source of truth for Island-created group chats.

#### 2. Signatures

- WebSocket attach: `ArchipelagoWSClient.attach(connectionId:sinceSeq:)`
- WebSocket events consumed by Island:
  - `status_changed` with `status`
  - `content_delta` with `text`
  - `permission_request`
  - `turn_complete`
- HTTP fallback: `ArchipelagoClient.conversationDetail(conversationId:)` calls `get_folder_conversation`.

#### 3. Contracts

- `GroupChat.GroupAgent.connectionId` maps a Archipelago Server runtime connection to a stored Island group agent.
- `status == .prompting && !isBlocked` means the agent is busy; all other states display as idle in the MVP.
- `content_delta.text` is buffered by `connectionId` only for the current turn.
- On `turn_complete`, Island must:
  - mark the matching agent idle,
  - write `latestResponseSummary`,
  - write `latestResponseAt`,
  - persist group chats,
  - open/focus the corresponding group detail in the island.
- If the buffered text is empty, Island may fetch `get_folder_conversation` and derive the latest assistant summary from persisted turns.
- Island must keep HTTP snapshot polling active for Island-created group chats, not only while a group detail screen is visible.
- If polling observes an agent transition from `prompting` to a non-prompting state without a pending permission, it must run the same completion path as `turn_complete`: fetch/buffer summary, persist `latestResponseSummary/latestResponseAt`, mark the agent idle, and open/focus the group detail.

#### 4. Validation & Error Matrix

- Unknown `connectionId` -> ignore the event; never create a group chat implicitly.
- Empty buffered response and failed HTTP fallback -> record a generic completion summary.
- WebSocket snapshot lacks live session for a known conversation -> mark the agent idle.
- WebSocket `turn_complete` missed but HTTP snapshot shows `prompting -> idle` -> derive summary with `get_folder_conversation` and present the group completion.
- Embedded Archipelago Server disconnected -> settings shows retryable Archipelago Server sync status; do not show CLI hook installation guidance.

#### 5. Good/Base/Bad Cases

- Good: an Island-created Archipelago Server conversation emits `content_delta` followed by `turn_complete`; Island opens the group detail and shows the latest answer summary.
- Base: no answer text is buffered, but `get_folder_conversation` has assistant turns; Island shows a summary from persisted history.
- Base: the separate Archipelago Server conversation window consumes the user workflow and Island misses the live completion event; snapshot polling still observes the idle transition and shows the latest response summary.
- Bad: Island asks users to install CLI hooks to see lifecycle state for Island-created group chats.

#### 6. Tests Required

- Run `swift build --product ArchipelagoApp` after changing this path.
- Run `zsh scripts/launch-packaged-app.sh` before manual testing integrated Island + embedded Archipelago Server behavior.
- Verify settings no longer contains CLI hook installation controls.
- Manually verify a Archipelago Server reply changes the agent to busy while streaming and idle after completion, opens the matching group detail, and shows the latest summary in both the group list and group detail.

#### 7. Wrong vs Correct

#### Wrong

```swift
// Hook status decides whether Island group chat agents are live.
if !model.hasAnyInstalledAgent {
    installHooksHint
}
```

#### Correct

```swift
// Archipelago Server runtime events decide Island-created group chat lifecycle.
archipelago.onAgentTurnCompleted = { completion in
    presentArchipelagoTurnCompletion(completion)
}
```

---

### Scenario: Closed Island Archipelago Server Status Projection

#### 1. Scope / Trigger

- Trigger: the collapsed Island surface needs to mirror Island-created Archipelago Server group-chat state.
- Applies to `AppModel.islandClosedMode`, `AppModel.islandClosedRightSlotContent()`, `V6ClosedPill`, and both external-display and MacBook-notch closed layouts.

#### 2. Signatures

- Busy source: `archipelago.groupChats[*].agents[*].displayStatus`.
- Count source: `archipelago.groupChats.count`.
- Closed-mode output: `UnifiedBars.Mode`.
- Closed right-slot output: `IslandRightSlotContent?`.

#### 3. Contracts

- `AgentDisplayStatus.working` is the only Archipelago Server state that should drive the closed Island left glyph into `UnifiedBars.Mode.running`.
- Legacy `surfacedSessions` attention states still take precedence over Archipelago Server running state and should return `.waiting`.
- When `archipelago.groupChats.count > 0`, the closed Island right slot shows `.count(archipelago.groupChats.count)` so the pill reflects the current Island group-chat count.
- `ArchipelagoCoordinator` runtime changes must notify `AppModel`, and `AppModel` must mirror the minimum closed-Island Archipelago Server state into its own observable snapshot. Do not rely on a SwiftUI view indirectly tracking nested `ArchipelagoCoordinator.groupChats` through a computed property.
- The projection must live in `AppModel` derived state, not inside `V6ClosedPill`, because `V6ClosedPill` is also used by appearance previews and should remain a pure renderer.
- External-display and MacBook-notch variants must use the same derived `mode` and `rightSlot`; layout differences stay inside `V6ClosedPill`.

#### 4. Validation & Error Matrix

- No Archipelago Server group chats -> fall back to the user's existing `islandRightSlot` preference and legacy session-derived content.
- Archipelago Server group chats exist but no agent is working -> left glyph is idle unless legacy sessions require waiting/running.
- One or more Archipelago Server agents are working -> left glyph is running unless legacy sessions require waiting.
- Archipelago Server coordinator disconnected but persisted group chats exist -> count may still display persisted group-chat count; do not create implicit chats.
- Archipelago Server runtime status changes but `AppModel` snapshot is unchanged -> no overlay refresh is required.

#### 5. Good/Base/Bad Cases

- Good: a Archipelago Server agent starts prompting while Island is collapsed; both external and notch pills show animated bars and the group count.
- Base: no agent is prompting; the collapsed pill still shows the group count but the glyph is idle.
- Bad: the closed pill reads Archipelago Server directly or duplicates layout-specific status logic in external and notch branches.
- Bad: Archipelago Server group-agent status mutates only inside `ArchipelagoCoordinator`; the collapsed Island appears stale because `AppModel` never observes a local state change.

#### 6. Tests Required

- Run `swift build --product ArchipelagoApp` after changing closed Island state derivation.
- Run `git diff --check`.
- Launch the packaged app with `zsh scripts/launch-packaged-app.sh` before manual UI verification.
- Manually verify a Archipelago Server reply makes the collapsed Island left glyph animate and the right slot count match the number of Island group chats.

#### 7. Wrong vs Correct

#### Wrong

```swift
// Renderer reaches into Archipelago Server and forks behavior by layout.
V6ClosedPill(mode: model.archipelago.groupChats.isEmpty ? .idle : .running, ...)
```

#### Correct

```swift
archipelago.onGroupChatsChanged = { [weak self] in
    self?.syncArchipelagoClosedIslandSnapshot()
}

V6ClosedPill(
    mode: model.islandClosedMode,
    rightSlot: model.islandClosedRightSlotContent(),
    layout: layout
)
```

---

### Scenario: Group Collaboration Plan Projection

#### 1. Scope / Trigger

- Trigger: a primary group-agent conversation receives a recognized `@agent` / `@all` mention, or Island sends a group task with `collaborationMode: "auto"`, and Archipelago Server emits `group_collaboration_plan` before sending the enriched prompt.
- Applies to Archipelago Server `AcpConnectionsProvider`, Archipelago Server conversation live message rendering, Island `ArchipelagoCoordinator`, Island `GroupDetailView`, and local `GroupChat.GroupAgent` state.
- The plan event is a live UI signal; it is not a persisted conversation turn.

#### 2. Signatures

- Archipelago Server WebSocket event: `group_collaboration_plan`.
- Archipelago Server reducer action: `GROUP_COLLABORATION_PLAN`.
- Archipelago Server wire type: `GroupCollaborationMemberInfo`.
- Island payload type: `ArchipelagoGroupCollaborationPlanPayload`.
- Island state map: `collaborationMemberIdsByPrimaryConnection: [String: Set<String>]`.
- Island primary-agent update: `ArchipelagoCoordinator.setPrimaryAgent(groupId:agentId:)`.
- Island group task entry point: `ArchipelagoCoordinator.sendGroupTask(groupId:text:)`.
- Island prompt client signature:
  ```swift
  ArchipelagoClient.prompt(
      connectionId: String,
      text: String,
      folderId: Int?,
      conversationId: Int?,
      collaborationMode: ArchipelagoCollaborationMode
  ) async throws
  ```

#### 3. Contracts

- Archipelago Server converts `group_collaboration_plan.members` into a live `plan` block and appends skipped rows for `invalid_mentions`.
- Archipelago Server must filter group-member input chips to active members in the current group, excluding the current primary agent.
- Island group task submission must target the group's `primaryAgent`, not a selected child agent or a newly created orphan conversation.
- Island must send group tasks with `collaborationMode == .auto`; ordinary Archipelago Server chat input continues to default to `mention`.
- If the primary agent has no live connection but already has a bound `conversationId`, Island may create a new connection, persist it to `group_agent.connection_id`, subscribe to events, and send against the existing `conversationId`.
- Before the prompt request completes, Island may optimistically mark the primary agent `.prompting` and set a short "task sent/decomposing" summary.
- If sending fails, Island must restore the primary agent to idle/connected state, clear the transient response buffer for that connection, surface a group-level error, and reload the server group projection.
- Island must use `members[*].agent_id` to mark delegated group agents `.prompting` and set a short "collaboration started" summary.
- Island must key the delegated-member set by the primary connection id. When the primary agent completes, those delegated members return to idle and receive the final response summary timestamp.
- When `delegate_to_agent` starts a child session, Island may temporarily bind the matching group member to the child `connection_id`. While that binding is active, `list_groups`, primary conversation snapshots, and `status_changed: connected` must not overwrite the child member back to the persisted group-agent connection or idle state.
- A delegated child member completes only after Island has a real child result summary from buffered child content, child conversation detail, or the `delegate_to_agent` structured output. Do not use the generic `"Agent 已完成回复。"` polling fallback for delegated children.
- `meta["archipelago.delegation"].status == "completed"` marks the parent `delegate_to_agent` tool lifecycle as terminal; it is not by itself a reason to clear a child member to idle unless a real summary can be derived.
- Empty plans clear any stored collaboration-member mapping for that primary connection and should not mark unrelated members busy.
- The group detail primary-agent star is optimistic local state backed by `ArchipelagoClient.updateGroup(id:primaryAgentId:)`; failures must roll back and reload the server projection.

#### 4. Validation & Error Matrix

- Unknown `group_id` in a plan -> ignore; never create a group implicitly.
- Island group task send with no primary agent -> show group error and do not call `acp_prompt`.
- Island group task send with no folder or no primary `conversationId` -> show group error and do not create a detached conversation.
- Island group task send while another send for the same group is pending -> ignore the second submit.
- `acp_prompt` failure -> rollback optimistic primary busy state and reload groups.
- Invalid mentions in Archipelago Server -> show skipped plan entries, but do not mark Island members busy.
- Primary agent completes without a stored collaboration-member mapping -> only the primary agent completion path runs.
- Delegated child `turn_complete` arrives before a child summary is available -> keep the child member busy and wait for delegation terminal output or conversation detail; do not show a completed fallback summary.
- `setPrimaryAgent` receives a non-member `agentId` or malformed ids -> return without sending a server mutation.
- `updateGroup` primary-agent update fails -> restore the previous primary id, show group error text, persist, and reload groups.

#### 5. Good/Base/Bad Cases

- Good: user sends `@codex @gemini` from the primary group conversation; Archipelago Server shows a plan, Island marks Codex and Gemini busy, and all members return idle after the primary final answer.
- Good: user types a requirement in Island's group task composer; Island sends it to the primary agent with `collaborationMode: "auto"`, Archipelago Server emits a plan for all active non-primary members, Island marks them busy, and the primary final answer becomes the latest summary.
- Good: user clicks the star beside an Island group member; Island immediately reflects the new primary agent and then applies the returned Archipelago Server projection.
- Base: user mentions `@open_code` when OpenCode is not an active member; Archipelago Server shows a skipped row and Island does not change any member status for that mention.
- Bad: plan rendering is persisted as a normal assistant message.
- Bad: Island infers delegated members from display names or agent types instead of stable `group_agent.id`.

#### 6. Tests Required

- Run `cargo test --lib group_collaboration --no-default-features` after changing plan generation.
- Run `pnpm build` after changing Archipelago Server plan rendering or input chips.
- Run `swift build --product ArchipelagoApp` after changing Island plan projection or primary-agent switching.
- Manually verify Island group task composer can start a primary-agent turn without typing `@all`.
- Manually verify group-member chips insert `@agent_type` and `@all`, the Archipelago Server live plan appears, Island delegated members become busy, and primary completion restores them idle.

#### 7. Wrong vs Correct

#### Wrong

```swift
// Agent type can collide across groups and does not identify a concrete group member.
let delegated = payload.members.map(\.agentType)
```

#### Correct

```swift
// Use the stable group_agent id from Archipelago Server's plan event.
let memberIds = Set(payload.members.map { String($0.agentId) })
collaborationMemberIdsByPrimaryConnection[connectionId] = memberIds
```

#### Wrong

```swift
// Creates a detached Archipelago Server conversation, so the visible group workspace
// and Island status projection do not share the same lifecycle.
let connectionId = try await client.connect(agentType: primary.agentType, workingDir: primary.workingDir)
try await client.prompt(connectionId: connectionId, text: task)
```

#### Correct

```swift
// Reuse or reconnect the primary group-agent binding and ask Archipelago Server
// for automatic group collaboration.
let target = try await ensurePrimaryAgentConnection(client: client, groupId: groupId)
try await client.prompt(
    connectionId: target.connectionId,
    text: task,
    folderId: target.folderId,
    conversationId: target.conversationId,
    collaborationMode: .auto
)
```

#### Wrong

```tsx
// Persists a transient collaboration plan as conversation content.
appendMessage({ role: "assistant", content: planText })
```

#### Correct

```tsx
// Renders the plan only in the live message state.
dispatch({ type: "GROUP_COLLABORATION_PLAN", contextKey, groupName, members, invalidMentions })
```

---

### Scenario: Archipelago Server Sidebar Runtime Status Projection

#### 1. Scope / Trigger

- Trigger: Archipelago Server sidebar conversation rows need to show whether an agent is actively replying.
- Applies to `SidebarConversationList`, `SidebarConversationCard`, `useConnection`, `ConversationStatusDot`, and ACP connection `status_changed` events.
- This is a UI runtime projection; it must not mutate the persisted conversation workflow status.

#### 2. Signatures

- Canonical conversation context key: `conv-{folderId}-{agentType}-{conversationId}`.
- Open tab context key: `tab.id`, which can be a draft `new-*` id after a new conversation is bound to a DB row.
- Runtime status source: `useConnection(connectionContextKey).status`.
- Persisted workflow source: `DbConversationSummary.status`.

#### 3. Contracts

- The sidebar "Running" badge is shown only when the runtime ACP connection status is `prompting`.
- Persisted `conversation.status === "in_progress"` means the conversation workflow is unfinished; it does not mean the agent is currently replying.
- For opened conversations, the sidebar must subscribe to the tab's actual `tab.id` connection key. This preserves runtime state for newly-created conversations whose tab id remains `new-*` after binding to a DB conversation.
- For unopened conversations, the sidebar may fall back to the canonical context key. If no runtime connection exists, the row is idle.
- The status dot may reuse the `in_progress` color only for live `prompting`; idle unfinished conversations should not render the running dot.
- Right-click workflow status actions still operate on `DbConversationSummary.status`; do not replace the persisted status model with runtime ACP status.

#### 4. Validation & Error Matrix

- New conversation row with DB status `in_progress` and no prompt in flight -> no "Running" badge.
- Existing row opened in a tab with connection status `connected` -> no "Running" badge.
- Existing row opened in a tab with connection status `prompting` -> show "Running" badge and running dot.
- New conversation bound to a DB row while its tab id is still `new-*` -> sidebar uses the open tab id and still reflects `prompting`.
- Unknown or missing connection key -> treat as idle; never infer running from persisted `in_progress`.

#### 5. Good/Base/Bad Cases

- Good: a group chat creates Gemini, Codex, and Claude Code rows; before any prompt is sent, none shows "Running" even though their workflow status is `in_progress`.
- Good: when Codex is replying, only the Codex row with runtime `prompting` shows "Running".
- Base: a cancelled conversation still shows the cancelled badge from persisted status.
- Bad: `const isRunning = conversation.status === "in_progress"`.
- Bad: subscribing only to the canonical key, causing a newly-created `new-*` tab's active runtime state to disappear from the sidebar.

#### 6. Tests Required

- Run `pnpm build` after changing the sidebar runtime status projection.
- Run `git diff --check`.
- Manually verify creating/opening a group chat does not show every `in_progress` conversation as running, and sending a prompt only marks the active replying agent as running.

#### 7. Wrong vs Correct

#### Wrong

```tsx
const status = conversation.status as ConversationStatus
const isRunning = status === "in_progress"
```

#### Correct

```tsx
const { status: runtimeStatus } = useConnection(connectionContextKey)
const isRunning = runtimeStatus === "prompting"
```

---

### Scenario: Archipelago Server Group Sidebar Display Projection

#### 1. Scope / Trigger

- Trigger: Archipelago Server sidebar conversation rows need to present Island group-chat structure, not raw conversation titles.
- Applies to `SidebarConversationList`, `SidebarConversationCard`, `listGroups`, Island group events, and Archipelago Server group agent metadata.
- This is a display projection; it must not rewrite persisted conversation titles.

#### 2. Signatures

- Group snapshot API: `listGroups(): Promise<GroupChatWithAgents[]>`.
- Group event constants:
  - `ISLAND_GROUP_UPSERTED_EVENT = "island://group-upserted"`
  - `ISLAND_GROUP_DELETED_EVENT = "island://group-deleted"`
  - `ISLAND_AGENT_UPSERTED_EVENT = "island://agent-upserted"`
  - `ISLAND_AGENT_DELETED_EVENT = "island://agent-deleted"`
- Mapping key: `GroupAgentInfo.conversationId -> GroupConversationMeta`.
- Display title format: `{group.name}·{AGENT_LABELS[agent.agentType]}·{agent.role}`; if `agent.role.trim()` is empty, omit the role segment and trailing separator.
- Primary marker source: `group.primaryAgentId === agent.id`.

#### 3. Contracts

- Sidebar group-agent rows must derive display title and primary-agent badge from the latest group snapshot.
- The role segment is the stored `GroupAgentInfo.role`: Island-created agents use the role assigned during group creation or later editing; Archipelago Server-created group agents default to `Coder`.
- Conversation title is only the fallback when no group metadata exists.
- `conversationId` is the stable join key between a Archipelago Server conversation row and a group agent; do not infer group membership from display title prefixes.
- Island reconciliation must preserve an existing `GroupAgentInfo.conversationId`. Title normalization may create or fill a group-agent conversation only when `conversationId == null`; it must not replace an existing bound conversation because the raw conversation title differs from the workspace/group display title.
- Group/agent upsert and delete events must refresh the group projection and conversation list so CRUD changes are reflected without a manual refresh.
- The primary-agent indicator is UI-only and must not mutate group state.
- Other sidebar status projections still use runtime ACP state; group metadata only affects naming and primary-agent display.

#### 4. Validation & Error Matrix

- `conversationId == null` for a group agent -> skip it in the sidebar metadata map.
- `listGroups()` fails -> keep existing sidebar rows and log the failure; do not clear all titles.
- Group metadata missing for a conversation -> fall back to `conversation.title || untitled`.
- Group agent removed -> event refresh removes its mapped title/primary marker.
- Group primary agent changed -> event refresh updates only the affected primary marker.

#### 5. Good/Base/Bad Cases

- Good: Island creates group `11` in workspace `trellis_try`; Archipelago Server sidebar rows display `11·Claude Code·Reviewer`, `11·Codex·Coder`, etc., with only the primary agent starred.
- Good: changing the primary agent updates the sidebar star after the group-upsert event.
- Base: a normal non-group conversation still displays its persisted title.
- Bad: using duplicated raw titles like `11 · Codex` as the source of truth for group membership.
- Bad: writing `{group.name} · {agent}` back into every conversation title to make the sidebar look correct.

#### 6. Tests Required

- Run `pnpm build` after changing Archipelago Server sidebar group projection.
- Run `git diff --check`.
- Launch the packaged app with `zsh scripts/launch-packaged-app.sh` before manual UI verification.
- Manually verify the left sidebar title format, primary-agent marker, and group/agent CRUD refresh without manually reloading the workspace.

#### 7. Wrong vs Correct

#### Wrong

```tsx
const title = conversation.title
const isPrimary = title.startsWith(`${groupName} ·`)
```

#### Correct

```tsx
const meta = groupConversationMeta.get(conversation.id)
const title = meta?.title ?? conversation.title
const isPrimary = meta?.isPrimary === true
```

---

---

## Common Mistakes

<!-- State management mistakes your team has made -->

(To be filled by the team)
