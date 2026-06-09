# Codeg API Shape — Endpoints Used by Island

## Base URL
`http://127.0.0.1:3079` (Codeg Tauri app or codeg-server)

## Authentication
Bearer token in `Authorization` header: `Bearer {token}`

## REST Endpoints (all POST to `/api/{endpoint}`)

### Folder Management
| Endpoint | Request | Response | Status |
|---|---|---|---|
| `open_folder` | `{path: string}` | `{id: int, name: string, path: string}` | Used by Island |
| `list_folders` | `{}` | `[{id, name, path}]` | Available, not yet used |

### ACP Agent Management
| Endpoint | Request | Response | Status |
|---|---|---|---|
| `acp_list_agents` | `{}` | `[{agentType, name, description, available, enabled}]` | Used by Island |
| `acp_connect` | `{agentType: string, workingDir: string}` | `string` (connectionId) | Used by Island |
| `acp_disconnect` | `{connectionId: string}` | void | Used by Island |
| `acp_list_connections` | `{}` | `[{id, agentType, status}]` | Used by Island |
| `acp_preflight` | `{agentType: string}` | `{passed: bool, checks: [{name, passed, message?, details?}]}` | Defined, not called |
| `acp_get_agent_status` | `{agentType: string}` | `{agentType, available, enabled, installedVersion?}` | Defined, not called |

### Conversation Management
| Endpoint | Request | Response | Status |
|---|---|---|---|
| `list_conversations` | `{}` | `[{id, title?, agentType, folderPath?, folderName?, ...}]` | Defined, not called |

### Health Check
| Endpoint | Request | Response | Status |
|---|---|---|---|
| `health` | `{}` | `{status: "ok"}` | Used by ServerManager |

## WebSocket

### Connection
- URL: `ws://127.0.0.1:3079/ws/events`
- Auth: Bearer token via `Sec-WebSocket-Protocol` header

### Outgoing Messages (Island → Codeg)
```json
{"action": "attach", "subscriptionId": "...", "connectionId": "...", "sinceSeq": null}
{"action": "detach", "subscriptionId": "..."}
```

### Incoming Events (Codeg → Island)
```json
{"seq": 1, "connection_id": "...", "type": "content_delta", "text": "..."}
{"seq": 2, "connection_id": "...", "type": "tool_call", "tool_call_id": "...", "title": "...", "status": "...", "content": "..."}
{"seq": 3, "connection_id": "...", "type": "permission_request", "request_id": "...", "tool_call": {...}, "options": [...]}
{"seq": 4, "connection_id": "...", "type": "status_changed", "status": "prompting|connected|disconnected|error"}
{"seq": 5, "connection_id": "...", "type": "turn_complete", "stop_reason": "..."}
{"seq": 6, "connection_id": "...", "type": "delegation_started", "child_agent_type": "...", "child_connection_id": "...", "task": "..."}
```

### Events Relevant for Phase 1 Status Tracking
| Event Type | Maps To | Island Status |
|---|---|---|
| `status_changed` (status=prompting) | Agent is working | Green dot |
| `status_changed` (status=connected) | Agent is idle | Gray dot |
| `permission_request` | Agent needs approval | Orange dot |
| `turn_complete` | Agent finished a turn | Gray dot (idle) |
| `status_changed` (status=disconnected/error) | Agent down | Red dot or hidden |

## JSON Key Convention
- Codeg API returns **snake_case** keys
- Island's `CodegClient` uses `convertFromSnakeCase` key decoding
- Island's `CodegClient` sends **camelCase** keys (default Swift JSON encoding)
- Codeg Axum backend accepts both (serde is case-insensitive for known fields)

## Deep Link (to be added)
- URL scheme: `codeg://`
- Format: `codeg://workspace?folderId=X&conversationId=Y&agent=Z`
- Handled by `deep-link-bootstrap.tsx` in Codeg frontend
- Currently only reads from `window.location.search` — needs extension to handle Tauri deep-link events
