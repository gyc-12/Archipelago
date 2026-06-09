# Island Swift Patterns — Frontend Structure Spec

## Architecture

Island is a native macOS Swift 6.2 app (SwiftUI + AppKit). The Codeg subsystem lives at `Sources/OpenIslandApp/Codeg/`.

### State Management Pattern
- `@Observable` + pure reducer pattern
- Central `AppModel` (@MainActor @Observable) owns all state, passed to all views
- Coordinators split out of AppModel: `CodegCoordinator`, `OverlayUICoordinator`, etc.
- `SessionState.apply(_ event: AgentEvent)` is the single mutation entry point for session data

### Codeg Subsystem File Layout
```
Sources/OpenIslandApp/Codeg/
  CodegCoordinator.swift    — @Observable coordinator: state + navigation + boot
  CodegClient.swift         — actor-based HTTP client (POST to Codeg API)
  CodegWSClient.swift       — WebSocket client for real-time events
  CodegServerManager.swift  — Process manager for Codeg binary
  CodegTypes.swift          — All data models (enums, structs, Codable types)
  GroupChatListView.swift   — SwiftUI list view for group chats
  CreateGroupChatView.swift — SwiftUI form for creating group chats
  GroupDetailView.swift     — SwiftUI detail view for a group chat
  ChatWindowView.swift      — SwiftUI chat message view (out of scope for Phase 1)
  ChatWindowController.swift — NSWindow + WKWebView manager
  AgentSDKSettingsPane.swift — Settings pane for agent SDKs
```

### Navigation Pattern
Navigation state is an enum on `CodegCoordinator`:
```swift
enum CodegContentState: Equatable {
    case chatList
    case createChat
    case addAgents(groupId: String)
    case groupDetail(groupId: String)
}
```
Navigation methods: `navigateToCreate()`, `navigateToAddAgents(groupId:)`, `navigateToDetail(groupId:)`, `navigateBack()`

### View Pattern
- Views take `CodegCoordinator` via `@Environment` or direct binding
- Chinese UI strings hardcoded (no i18n framework)
- SF Symbols for icons
- Color palette via SwiftUI `Color` initializers
- Standard SwiftUI layout: `VStack`, `HStack`, `ScrollView`, `LazyVStack`

### Concurrency
- `CodegClient` is an `actor` (thread-safe)
- `CodegCoordinator` is `@MainActor @Observable`
- Async/await throughout, `Task { }` for fire-and-forget
- Errors caught with `do/catch` + `NSLog`

### Key Integration Points
- `AppModel` owns `codeg: CodegCoordinator` (line 71 of AppModel.swift)
- `AppModel` owns `chatWindows: ChatWindowController` (line 72)
- Codeg views rendered inside `IslandPanelView` when `IslandSurface` is set appropriately
