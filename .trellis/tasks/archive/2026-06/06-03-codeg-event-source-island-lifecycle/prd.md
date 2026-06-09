# Codeg Event Source for Island Lifecycle

## Goal

Move Island runtime awareness for user-facing group chats from CLI hook events to the embedded Codeg event source. Island should only maintain group chats created in Island, and should show real-time agent status plus the latest completed response summary from Codeg conversations without requiring CLI hook installation.

## What I Already Know

* The product direction is to only maintain group chats created from Island.
* Island already starts embedded Codeg and stores group chats with Codeg `conversationId` and optional `connectionId`.
* Island already has HTTP access to Codeg (`CodegClient`) and WebSocket attach support (`CodegWSClient`).
* Codeg provides runtime session snapshots by conversation and emits ACP events including status changes, content deltas, permission requests, and turn completion.
* Existing Island hook install/setup UI should be removed from settings for this app direction.

## Assumptions

* External terminal sessions that bypass Codeg are out of scope for this task.
* The MVP only needs to synchronize Island-created Codeg conversations.
* "Agent finished" means Codeg emits `turn_complete` for the relevant `connectionId`.
* The first visible version can use a plain text summary derived from the latest streamed assistant text.

## Requirements

* Island must use Codeg HTTP/WS as the source of truth for group chat agent lifecycle.
* When a group agent is prompting, Island shows the agent as busy.
* When Codeg emits `turn_complete`, Island updates that agent to idle and records a latest response summary.
* When an agent finishes, Island should open/expand and focus the corresponding group chat so the user can see which group and agent completed.
* Group detail/list UI should expose the latest agent response summary.
* Remove Island CLI hooks installation/setup UI from settings.
* Remove or disable hook-driven runtime listening from the app path so the primary lifecycle is Codeg-driven.

## Acceptance Criteria

* [ ] A message sent in a Codeg conversation for an Island-created group updates the matching Island agent status in real time.
* [ ] On `turn_complete`, Island opens the island and displays the group plus the agent's latest response summary.
* [ ] Settings no longer shows CLI hook installation controls.
* [ ] The app builds with `swift build --product OpenIslandApp`.
* [ ] The packaged app launch script still succeeds.

## Out of Scope

* Monitoring arbitrary external Claude/Codex terminal sessions.
* Rebuilding Codeg's full chat transcript UI inside Island.
* Multi-agent delegation transcript rendering beyond a latest summary signal.
* Removing all hook source files from the package if doing so would create avoidable packaging risk in this iteration.

## Technical Notes

* Relevant Island files: `CodegCoordinator.swift`, `CodegTypes.swift`, `CodegWSClient.swift`, `GroupChatListView.swift`, `GroupDetailView.swift`, `SettingsView.swift`, `AppModelTypes.swift`, `OpenIslandApp.swift`.
* Relevant Codeg files: `src/contexts/acp-connections-context.tsx`, `src/lib/api.ts`, `src-tauri/src/web/ws.rs`, `src-tauri/src/web/router.rs`.
* Codeg event source already supports WebSocket attach by `connectionId`; Island should extend its handler beyond status events to capture response text.
