# Island-Codeg CRUD Sync Planning

## Goal

Plan the next stage of Island and Codeg integration: group chats/workspaces and agents must be create/read/update/delete synced between Island and Codeg, so users can manage the same collaboration structure from either UI.

## What I already know

- Current worktree is clean after the user's rollback.
- The only existing cross-app linkage is: Island creates a local `GroupChat`, creates Codeg folder/conversation rows, and double-clicking the Island group opens Codeg `/workspace?folderId=...&conversationId=...&agent=...`.
- Island currently owns group chats in local JSON through `CodegGroupChatStore`.
- Codeg currently owns workspace/folder state in its database:
  - `folder` / `FolderDetail`
  - `conversation` / `DbConversationSummary`
  - `opened_tab`
- Codeg workspace removal is `removeFolderFromWorkspace(folderId)`: it removes the folder from the open workspace and closes tabs; it does not physically delete the directory.
- Product decision: workspace removal should remove matching Island group chats from the visible UI, but should not physically delete project files. Prefer Codeg-side soft delete / inactive metadata over hard deletion where practical.
- Codeg already has a global `/ws/events` WebSocket firehose and `EventEmitter`; Island already connects to this WebSocket for ACP/runtime events.
- Codeg folder commands currently emit events for some workspace actions, but not a dedicated Island group/workspace CRUD event stream.

## Product Framing

- User-visible Island "群聊" maps to Codeg "workspace/folder plus one or more agent conversations".
- A group chat is not just a folder: it also needs agent membership, role, primary agent, conversation binding, and runtime binding.
- This app only needs to maintain group chats created/managed through Island/embedded Codeg, not arbitrary historical Codeg conversations.

## Recommended Architecture

Use Codeg embedded server as the source of truth for group-chat metadata, and make Island a client/projection.

### Data Model

Add a Codeg-side group model:

- `group_chat`
  - `id`
  - `name`
  - `folder_id`
  - `folder_path`
  - `primary_agent_id`
  - `created_at`
  - `updated_at`
  - `deleted_at` or active flag if soft delete is needed
- `group_agent`
  - `id`
  - `group_id`
  - `agent_type`
  - `role`
  - `conversation_id`
  - `connection_id`
  - `working_dir`
  - `created_at`
  - `updated_at`

Island `GroupChat.id` should become the Codeg `group_chat.id` serialized as a string. Island agent IDs should become Codeg `group_agent.id` serialized as strings.

### API

Add Codeg HTTP APIs:

- `list_groups`
- `create_group`
- `update_group`
- `delete_group`
- `add_group_agent`
- `update_group_agent`
- `remove_group_agent`

Response shape should be stable and nested:

```json
{
  "group": {},
  "agents": []
}
```

### Event Sync

Add global WebSocket events through the existing Codeg event bridge:

- `island://group-upserted`
- `island://group-deleted`
- `island://agent-upserted`
- `island://agent-deleted`

Island should subscribe to the existing `/ws/events` global stream, handle these events, and call `list_groups` as a fallback resync if it detects an unknown/out-of-order condition.

### Direction Rules

- Island create group:
  1. `open_folder`
  2. `create_group`
  3. `create_conversation` per selected agent
  4. `add_group_agent`
  5. `update_group(primaryAgentId)`
  6. refresh from `list_groups`
- Island delete group:
  1. disconnect active agent connections
  2. `delete_group`
  3. optionally `remove_folder_from_workspace` for the folder if this group owns the workspace
- Island add/remove agent:
  - create/remove Codeg conversation binding and group-agent row
  - preserve existing ACP runtime status sync through `connectionId`
- Codeg remove workspace:
  - existing `removeFolderFromWorkspace(folderId)` should emit an Island sync event
  - Island removes all group chats whose `folder_id` matches that folder
- Codeg open workspace:
  - if it corresponds to an existing group, Island updates the group projection
  - if no group exists, MVP should not implicitly create an Island group unless the user explicitly creates/imports one

## MVP Scope

- Codeg becomes source of truth for Island-created group chats and group agents.
- Island boot loads groups from Codeg instead of local JSON.
- Island group list/detail updates in response to Codeg WebSocket sync events.
- Island create/delete group and add/remove agent write through Codeg APIs.
- Codeg workspace removal deletes/removes matching Island group projections.
- Double-click Island group still opens Codeg workspace/conversation exactly as today.

## Explicit Out of Scope For MVP

- Importing every historical Codeg conversation into Island groups.
- Automatically creating Island group chats for every Codeg-opened workspace.
- Physical filesystem deletion.
- Complex conflict resolution UI.
- Multi-device/cloud synchronization beyond the embedded Codeg server database.

## Open Questions

- Resolved: when Codeg removes a workspace, Island should remove the group from the visible UI, while Codeg keeps group metadata as inactive/soft-deleted where practical. MVP behavior is "visibly removed, recoverable later if we add restore/import UI".

## Acceptance Criteria

- [ ] Island-created group chats are persisted in Codeg and survive Island local JSON deletion.
- [ ] Creating/deleting a group from Island updates Codeg workspace/conversation state.
- [ ] Removing a workspace from Codeg removes the matching group from Island without restarting the app.
- [ ] Adding/removing an agent from Island updates Codeg and Island consistently.
- [ ] Codeg-side changes are delivered to Island through WebSocket events with HTTP resync fallback.
- [ ] Existing runtime status and latest reply summary sync keep working.
- [ ] Double-clicking an Island group still opens the correct Codeg workspace/conversation.

## Technical Notes

- Relevant Island files:
  - `agentsIsland/open-vibe-island/Sources/OpenIslandApp/Codeg/CodegClient.swift`
  - `agentsIsland/open-vibe-island/Sources/OpenIslandApp/Codeg/CodegCoordinator.swift`
  - `agentsIsland/open-vibe-island/Sources/OpenIslandApp/Codeg/CodegTypes.swift`
  - `agentsIsland/open-vibe-island/Sources/OpenIslandApp/Codeg/CodegWSClient.swift`
- Relevant Codeg files:
  - `agentsIsland/codeg-main/src-tauri/src/commands/folders.rs`
  - `agentsIsland/codeg-main/src-tauri/src/models/folder.rs`
  - `agentsIsland/codeg-main/src-tauri/src/models/conversation.rs`
  - `agentsIsland/codeg-main/src-tauri/src/web/event_bridge.rs`
  - `agentsIsland/codeg-main/src/contexts/app-workspace-context.tsx`
  - `agentsIsland/codeg-main/src/contexts/tab-context.tsx`
- Cross-layer risk: API response shape must be explicit and tested. Previous exploration showed this is the likely failure point if Rust model serialization and Swift decoding drift.
