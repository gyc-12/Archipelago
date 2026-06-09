# Error Handling Spec — Island-Codeg Integration

## Scope
Phase 1 error handling is minimal ("core flow only"). No retry/reconnect/crash recovery.

## Island Side (Swift)

### Current Pattern
- All errors caught with `do { } catch { NSLog("...error: \(error)") }` — silently swallowed
- No user-facing error UI in Codeg views
- `CodegClient` throws on HTTP errors but coordinator catches all

### Phase 1 Minimum
| Scenario | Handling |
|---|---|
| Codeg app not found at configured path | Show error in Island settings pane with path configuration |
| Codeg app fails to start (health check timeout) | Set `isCodegConnected = false`, show "Codeg offline" indicator in chat list |
| `open_folder` fails | Log error, show inline error text in create view |
| `acp_connect` fails | Log error, show "connection failed" status on agent badge |
| WebSocket disconnects | Set connection status to disconnected, gray out status dots |
| HTTP request timeout (60s) | Catch timeout, log, no retry |

### Error Types (existing)
```swift
enum CodegError: Error {
    case httpError(String)
    case wsError(String)
}
```
No changes needed for Phase 1.

### Forbidden Patterns
- Do NOT add retry loops or exponential backoff (out of scope)
- Do NOT add reconnection logic for WebSocket (out of scope)
- Do NOT surface raw error messages to user — use friendly Chinese strings

## Codeg Side (Rust/TypeScript)

### Deep Link Error Handling
| Scenario | Handling |
|---|---|
| Invalid URL scheme received | Log warning, ignore — don't crash |
| `folderId` not found in database | Navigate to default workspace (no folder selected) |
| `conversationId` not found | Navigate to folder without opening a conversation |
| Malformed query params | Fall through to default workspace view |

### Existing Pattern
- Codeg Axum handlers return `Result<Json<T>, AppError>` with HTTP status codes
- Frontend shows toast notifications for API errors
- No changes needed to existing error handling for Phase 1
