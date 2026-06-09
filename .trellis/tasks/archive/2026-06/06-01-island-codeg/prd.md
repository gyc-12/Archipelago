# Island-Codeg 互联：群聊创建与跳转 (Phase 1)

## Goal

Connect Open Island's dynamic-island UI with Codeg's multi-agent workbench to deliver the first end-to-end flow of the AgentHub platform: users create multi-agent group chats in the Island overlay, preview agent status at a glance, and jump into Codeg's full conversation UI with one click.

## Decisions

### D1: Architecture — Single Process
- **What**: Island auto-starts the **Codeg Tauri desktop app** (not the headless codeg-server)
- **Why**: Tauri app embeds both API server (port 3079) and full UI — one process handles everything
- **How**: Island launches Codeg.app via `NSWorkspace.shared.open()`, waits for health check at `127.0.0.1:3079`, then connects

### D2: Data Model — Folder = Group Chat
- **What**: No new Codeg database table. A group chat = a Codeg folder + all ACP connections in that folder
- **Why**: Zero Codeg schema changes. All existing APIs (`open_folder`, `acp_connect`, `acp_list_connections`) are sufficient
- **Consequences**: Group name = folder basename. Any folder with active connections appears as a group chat in Island

### D3: Navigation — codeg:// URL Scheme
- **What**: Register `codeg://` custom URL scheme in Codeg Tauri app
- **Why**: Enables `NSWorkspace.shared.open(URL("codeg://workspace?folderId=X"))` from Island to launch+navigate Codeg
- **How**: Add `tauri-plugin-deep-link`, register scheme, forward URL params to existing `deep-link-bootstrap.tsx`

### D4: State — Codeg Backend is Source of Truth
- **What**: Island is a thin client. All agent/folder/conversation state lives in Codeg's SQLite
- **Why**: Single source of truth, no sync issues
- **How**: Island reads state via Codeg HTTP API, receives real-time updates via WebSocket

### D5: Design — Adapt Colors + Typography
- **What**: Apply DESIGN.md color palette + JetBrains Mono to Island's Codeg views, keep native SwiftUI patterns
- **Why**: Consistent visual language without forcing terminal aesthetics into a native overlay

### D6: MVP Scope — Core Flow Only
- **What**: Create chat → add agents → see status → click → jump to Codeg. No retry/reconnect/crash recovery
- **Why**: Minimum viable end-to-end flow; robustness comes in Phase 2

## Requirements

### R1: Codeg App Auto-Launch
- On Island boot, check if Codeg API is reachable at `127.0.0.1:3079/api/health`
- If not, launch Codeg.app via `NSWorkspace.shared.open()` with configurable app path
- Poll health endpoint (max 30 attempts, 200ms interval) before connecting
- Generate random bearer token per session (remove hardcoded `0f2111a9172646608f272a5138b65f72`)
- Store Codeg.app path in Settings (replace hardcoded dev-machine path)
- Wire up `CodegServerManager` in `CodegCoordinator.boot()` (currently dead code)

### R2: Group Chat Creation
- User taps "+" in expanded island → `CreateGroupChatView`
- Form fields:
  - **Workspace directory**: folder picker dialog (`NSOpenPanel`) — no freeform text input
  - Group name auto-derived from folder basename (e.g., `/Users/gyc/my-project` → "my-project")
- On submit: call `CodegClient.openFolder(path:)` to register folder in Codeg
- Navigate to agent selection step

### R3: Agent Addition
- After creating group chat, show agent selection (Phase 1: Claude Code + Codex only)
- For each selected agent: call `CodegClient.connect(agentType:workingDir:)`
- Wait for connection status to settle (existing polling logic in coordinator)
- Show connection status per agent (connecting → connected, or error)
- "Done" button returns to group chat list

### R4: Group Chat List & Status Overview
- Expanded island shows scrollable list of active group chats
- Data source: combine `CodegClient.listConversations()` + `CodegClient.listConnections()` grouped by folder
- Each row displays:
  - Folder name (as group chat title)
  - Agent badges: type-colored capsules (Claude=purple, Codex=green)
  - Status dot: green (any agent working), orange (agent blocked/permission-requested), gray (all idle/disconnected)
- Wire up `CodegWSClient` to receive real-time events:
  - `status_changed` → update agent status dots
  - `permission_request` → show orange blocked indicator
  - `turn_complete` → flip back to idle
- Design: apply DESIGN.md color tokens and JetBrains Mono typography

### R5: Deep Link Navigation to Codeg
**Island side:**
- Single-click a group chat row → call `NSWorkspace.shared.open(URL("codeg://workspace?folderId=\(folderId)")!)`
- This launches or activates Codeg Tauri app and navigates to the folder's workspace

**Codeg side (new work):**
- Add `tauri-plugin-deep-link` to Cargo.toml
- Register `codeg` URL scheme in `tauri.conf.json` → generates `Info.plist` entry
- Handle `deep-link://new-url` Tauri event in `lib.rs` or `main.rs`
- Forward parsed URL params (`folderId`, `conversationId`, `agent`) to the frontend via Tauri event
- Frontend: extend `deep-link-bootstrap.tsx` to also handle params from Tauri events (not just `window.location.search`)

### R6: Design Language Adaptation
Apply to all Island Codeg views (`GroupChatListView`, `CreateGroupChatView`, `GroupDetailView`):
- **Colors**: Canvas `#fdfcfc`, Ink `#201d1d`, Mute `#646262`, Hairline `rgba(15,0,0,0.12)`
  - Status: Success `#30d158`, Warning `#ff9f0a`, Danger `#ff3b30`, Accent `#007aff`
- **Typography**: JetBrains Mono (Berkeley Mono substitute) — body 16px/400, heading 16px/700, caption 14px/400
- **Shape**: 4px radius on interactive elements (buttons, badges), 0px on containers
- **Spacing**: 8px base unit, 16px row padding, 96px section gap (adapted for compact overlay)
- Note: Island's overlay panel itself stays dark (`surface-dark` background) — these design tokens apply to content within it

## Acceptance Criteria

- [ ] Island launches Codeg.app on boot and connects via health check
- [ ] User can create a group chat by selecting a workspace folder
- [ ] User can add Claude Code and/or Codex agents to a group chat
- [ ] Group chat list displays with folder name, agent badges, and status dots
- [ ] Agent status updates in real-time (green=working, orange=blocked, gray=idle)
- [ ] Clicking a group chat opens Codeg Tauri app at the correct folder
- [ ] No hardcoded tokens or developer-local paths in committed source
- [ ] Codeg views use DESIGN.md color palette + JetBrains Mono font

## Definition of Done

- Both Island and Codeg build and run successfully
- End-to-end flow tested: launch → create chat → add agents → see status → click → Codeg opens at folder
- No hardcoded secrets in source code

## Out of Scope (Phase 1)

- Agent types beyond Claude Code and Codex
- Sending messages / prompting agents from within Island
- Orchestrator / auto-delegation between agents
- Chat message preview in Island (only status overview)
- Disconnection handling / auto-reconnect / crash recovery
- Group chat deletion confirmation dialog
- Custom group chat names (independent of folder name)
- Mobile / watchOS companion apps
- Rich media cards (code diff, preview, deploy status)
- Multi-language / i18n

## Technical Notes

### Files to modify (Island — `agentsIsland/open-vibe-island/`)
| File | Changes |
|---|---|
| `Sources/OpenIslandApp/Codeg/CodegCoordinator.swift` | Wire up ServerManager + WSClient in `boot()`, remove hardcoded token, add folder-based group chat logic |
| `Sources/OpenIslandApp/Codeg/CodegClient.swift` | Call previously unused methods (`listConversations`, `getAgentStatus`) |
| `Sources/OpenIslandApp/Codeg/CodegServerManager.swift` | Fix binary path to configurable setting, align port with coordinator |
| `Sources/OpenIslandApp/Codeg/CodegWSClient.swift` | Already implemented — just needs to be initialized in coordinator |
| `Sources/OpenIslandApp/Codeg/CodegTypes.swift` | No schema changes needed — existing types sufficient |
| `Sources/OpenIslandApp/Codeg/GroupChatListView.swift` | Apply design tokens, add real-time status dots, wire up WebSocket state |
| `Sources/OpenIslandApp/Codeg/CreateGroupChatView.swift` | Replace text field with `NSOpenPanel` folder picker, derive name from path |
| `Sources/OpenIslandApp/Codeg/ChatWindowController.swift` | Replace WKWebView with `NSWorkspace.shared.open(codeg://...)` deep link |
| Settings pane | Add Codeg.app path configuration field |

### Files to modify (Codeg — `agentsIsland/codeg-main/`)
| File | Changes |
|---|---|
| `src-tauri/Cargo.toml` | Add `tauri-plugin-deep-link` dependency |
| `src-tauri/tauri.conf.json` | Register `codeg` URL scheme |
| `src-tauri/capabilities/default.json` | Add deep-link permission |
| `src-tauri/src/lib.rs` | Handle deep-link event, forward to frontend |
| `src/components/workspace/deep-link-bootstrap.tsx` | Handle params from Tauri deep-link event (in addition to URL query params) |

### Architecture diagram
```
┌─────────────────────────────────────────────────────────┐
│  Open Island (macOS notch overlay)                      │
│                                                         │
│  ┌─────────────┐  HTTP POST   ┌──────────────────────┐  │
│  │ CodegClient  │────────────→│  Codeg Tauri App     │  │
│  │ (REST API)   │             │  (port 3079)         │  │
│  └─────────────┘  ←───────── │                      │  │
│                    JSON resp   │  Axum API + SQLite   │  │
│  ┌─────────────┐              │  + Event Broadcaster │  │
│  │ CodegWSClient│  WebSocket  │                      │  │
│  │ (events)     │←───────────│  /ws/events           │  │
│  └─────────────┘              └──────────────────────┘  │
│                                         ↑                │
│  Click group chat:                      │                │
│  NSWorkspace.open("codeg://workspace    │                │
│    ?folderId=X")  ─────────────────────→│                │
│                     codeg:// URL scheme                  │
└─────────────────────────────────────────────────────────┘
```

### Implementation order (suggested subtasks)
1. **T1: Fix Codeg app launch** — wire up CodegServerManager in coordinator, configurable path, health check, dynamic token
2. **T2: Group chat creation** — folder picker, open_folder API call, agent selection (Claude Code + Codex)
3. **T3: WebSocket wiring** — initialize WSClient in coordinator, subscribe to connection events, update status
4. **T4: Group chat list UI** — apply design tokens, real-time status dots, folder-based grouping
5. **T5: Codeg deep link** — add tauri-plugin-deep-link, register codeg:// scheme, handle in frontend
6. **T6: Navigation** — click handler in Island opens codeg:// URL, replace ChatWindowController WKWebView logic
