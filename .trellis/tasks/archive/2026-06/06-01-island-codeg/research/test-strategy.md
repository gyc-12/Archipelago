# Test Strategy — Island-Codeg Integration

## Island (Swift — XCTest)

### Existing Test Infrastructure
- `Tests/OpenIslandCoreTests/` — 20+ test files for core library
- `Tests/OpenIslandAppTests/` — 14 test files for app layer
- Test runner: Swift Package Manager (`swift test`)
- Pattern: `XCTestCase` subclasses, `@Test` attribute (Swift Testing), async tests

### Phase 1 Tests to Add

#### Unit Tests (OpenIslandCoreTests)
None needed — no core library changes in Phase 1.

#### App Tests (OpenIslandAppTests)
| Test | What it verifies |
|---|---|
| `CodegCoordinatorBootTests` | `boot()` launches Codeg app, waits for health check, connects |
| `CodegCoordinatorGroupChatTests` | Creating group chat calls `openFolder`, correct state transitions |
| `CodegCoordinatorAgentTests` | Adding agents calls `connect`, status updates on events |
| `CodegServerManagerTests` | Server start with dynamic token, health check polling |

#### Test Approach
- Mock `CodegClient` as a protocol to inject test doubles
- Test coordinator state transitions without real HTTP calls
- Verify navigation state machine transitions
- Test design token values are correct (color hex, font name)

### Manual E2E Test Checklist
- [ ] Launch Island → Codeg app starts automatically
- [ ] Create group chat via folder picker → folder opens in Codeg
- [ ] Add Claude Code agent → connection established
- [ ] Add Codex agent → connection established
- [ ] Group chat list shows both agents with status dots
- [ ] Prompt an agent in Codeg → status dot turns green in Island
- [ ] Agent finishes → status dot turns gray
- [ ] Click group chat in Island → Codeg app activates at correct folder

## Codeg (TypeScript — Vitest / Rust — cargo test)

### Phase 1 Tests to Add

#### Frontend (Vitest)
| Test | What it verifies |
|---|---|
| `deep-link-bootstrap.test.ts` | Parses `codeg://` URL params correctly |
| `deep-link-bootstrap.test.ts` | Handles missing/invalid params gracefully |
| `deep-link-bootstrap.test.ts` | Handles Tauri event-based params (not just URL query) |

#### Backend (Rust — cargo test)
No new Rust tests needed — deep link handling is in the Tauri plugin + frontend layer.

### What NOT to Test
- Existing Codeg API endpoints (already tested)
- Codeg conversation/folder CRUD (already tested)
- WebSocket event broadcasting (already tested)
- Island's existing session monitoring features (unchanged)
