# Error Handling

> How runtime and integration errors are handled in this project.

---

## Scenario: Integrated Archipelago Manual Launch

### 1. Scope / Trigger

- Trigger: any manual test or debug run that needs the real integrated Archipelago app with the embedded collaboration runtime.
- Applies to group chat creation, embedded runtime startup, workspace loading, agent status sync, runtime settings, Web service, and ACP SDK behavior.

### 2. Signatures

- Preferred command:
  ```bash
  cd apps/archipelago-macos
  zsh scripts/launch-packaged-app.sh
  ```
- Underlying package command:
  ```bash
  ARCHIPELAGO_RUNTIME_SKIP_BUILD=true \
  ARCHIPELAGO_SKIP_BRAND_GENERATION=true \
  ARCHIPELAGO_SKIP_DMG=true \
  zsh scripts/package-app.sh
  ```
- App path opened by the launch script:
  ```text
  apps/archipelago-macos/output/package/Archipelago.app
  ```

### 3. Contracts

- `ARCHIPELAGO_RUNTIME_SKIP_BUILD=true`: reuse existing production-ready runtime `out/`, `archipelago-server`, and `archipelago-mcp` artifacts.
- `ARCHIPELAGO_SKIP_BRAND_GENERATION=true`: reuse existing brand assets and avoid regenerating icon files during ordinary manual launch.
- `ARCHIPELAGO_SKIP_DMG=true`: produce only the `.app` and `.zip`; DMG creation is not needed for development manual testing.
- Legacy `OPEN_ISLAND_*` variables remain compatibility fallbacks, but new docs and scripts should use `ARCHIPELAGO_*`.
- The packaged app must contain:
  - `Contents/Helpers/archipelago-server`
  - `Contents/Helpers/archipelago-mcp`
  - `Contents/Resources/ArchipelagoWeb/index.html`
- The packaged app launch must use `open -n "$bundle_dir"` with the absolute bundle path. Do not use `open -na` with a path.

### 4. Validation & Error Matrix

- Missing `archipelago-server`, `archipelago-mcp`, or `ArchipelagoWeb/index.html` -> package script must fail before launch.
- Packaged smoke health check fails -> do not open the app for manual testing; fix embedded Archipelago Server runtime first.
- `open` reports "Unable to find application named ..." -> the launch command used the wrong `open` mode; use `open -n "$bundle_dir"`.
- Manual test sees an old dev app bundle -> wrong launch path; stop it and launch `output/package/Archipelago.app`.

### 5. Good/Base/Bad Cases

- Good: `zsh scripts/launch-packaged-app.sh` passes packaged smoke and opens `output/package/Archipelago.app`; embedded runtime starts from the app bundle.
- Base: package script rebuilds the Swift app, reuses existing Archipelago Server artifacts, skips DMG, then opens the packaged app for manual testing.
- Bad: launching an old dev bundle can exercise a different bundle/runtime path and has already caused manual testing against the wrong app.

### 6. Tests Required

- Before asking for manual testing of integrated Island + Archipelago Server behavior, run `zsh scripts/launch-packaged-app.sh`.
- Confirm package smoke output includes:
  - `Bundle structure verified.`
  - `Smoke test passed`
  - `Bundle: .../output/package/Archipelago.app`
- Confirm a running app process after launch with `pgrep -af 'ArchipelagoApp|archipelago-server'`.

### 7. Wrong vs Correct

#### Wrong

```bash
cd apps/archipelago-macos
swift run ArchipelagoApp
```

#### Correct

```bash
cd apps/archipelago-macos
zsh scripts/launch-packaged-app.sh
```

---

## Scenario: Embedded Archipelago Server LAN Web Service

### 1. Scope / Trigger

- Trigger: Island embeds Archipelago Server and must expose the original Archipelago Server Web service page to other LAN devices.
- Applies to `ArchipelagoEmbeddedRuntimeConfig`, `ArchipelagoServerManager`, `ChatWindowController`, Archipelago Server `/settings/web-service`, HTTP API auth, and WebSocket auth.

### 2. Signatures

- Island embedded env keys:
  ```text
  ARCHIPELAGO_SERVER_HOST
  ARCHIPELAGO_SERVER_PORT
  ARCHIPELAGO_SERVER_TOKEN
  ARCHIPELAGO_SERVER_DATA_DIR
  ARCHIPELAGO_SERVER_STATIC_DIR
  ARCHIPELAGO_SERVER_PATH
  ```
- Archipelago Server server env consumed by `archipelago-server`:
  ```text
  ARCHIPELAGO_HOST
  ARCHIPELAGO_PORT
  ARCHIPELAGO_TOKEN
  ARCHIPELAGO_DATA_DIR
  ARCHIPELAGO_STATIC_DIR
  ```
- Internal Island URL:
  ```text
  http://127.0.0.1:<port>
  ```

### 3. Contracts

- Embedded Archipelago Server must default `ARCHIPELAGO_HOST` to `0.0.0.0` so the original Archipelago Server Web service is reachable from the LAN.
- `ARCHIPELAGO_SERVER_HOST` may override the bind host; blank values fall back to `0.0.0.0`.
- Legacy `OPEN_ISLAND_ARCHIPELAGO_*` variables remain compatibility fallbacks.
- `ArchipelagoServerManager.baseURL` must stay loopback (`127.0.0.1`) for Island internal health checks, API calls, and WKWebView navigation.
- Island internal Archipelago Server windows inject `archipelago_token` into localStorage at document start, so double-click/open-conversation keeps working without a login prompt.
- Island internal Archipelago Server windows also inject `archipelago_island_embedded=true`; Archipelago Server settings use this marker to keep the original Web service nav item visible even though the transport runtime is technically `web`.
- User-facing LAN URL and token discovery belongs to Archipelago Server's original `/settings/web-service` page. Do not duplicate a second Island Web-service settings surface unless product scope explicitly changes.
- External API and WebSocket access must keep using Archipelago Server's existing token middleware. Static page load may be public, but `/api/*` and WS traffic require the token.

### 4. Validation & Error Matrix

- Embedded `archipelago-server` listens on `127.0.0.1:<port>` only -> LAN browser cannot connect; check `ARCHIPELAGO_HOST` and `ARCHIPELAGO_SERVER_HOST`.
- `lsof -nP -iTCP:<port> -sTCP:LISTEN` shows `*:port` -> LAN binding is active.
- `POST /api/health` without `Authorization: Bearer <token>` -> HTTP 401.
- `POST /api/health` with the embedded token on `127.0.0.1` -> HTTP 200.
- `POST /api/health` with the embedded token on the machine LAN IP -> HTTP 200.
- Island WKWebView prompts for token -> token injection or internal base URL routing regressed.
- Island Archipelago Server settings sidebar lacks "Web service" -> `archipelago_island_embedded` injection or Archipelago Server settings-shell filtering regressed.

### 5. Good/Base/Bad Cases

- Good: packaged Island launches embedded Archipelago Server, Archipelago Server `/settings/web-service` lists loopback and LAN URLs, LAN URL works after entering the token, and Island double-click still opens conversations directly.
- Base: developer overrides `ARCHIPELAGO_SERVER_HOST=127.0.0.1` for local-only debugging and accepts that LAN access is disabled.
- Bad: changing `ArchipelagoServerManager.baseURL` to `0.0.0.0` or a LAN IP; this breaks internal same-origin assumptions and is not needed for LAN exposure.
- Bad: adding an Island-only token/URL UI while Archipelago Server's original Web service page already owns the display and controls.

### 6. Tests Required

- Run `swift test --filter ArchipelagoGroupChatTests` after changing embedded Archipelago Server runtime config.
- Assert `ArchipelagoEmbeddedRuntimeConfig.environment["ARCHIPELAGO_HOST"] == "0.0.0.0"` by default.
- Assert `ARCHIPELAGO_SERVER_HOST` override is honored and blank override falls back to `0.0.0.0`.
- Assert legacy `OPEN_ISLAND_ARCHIPELAGO_*` fallbacks still resolve.
- Assert `withPort(_:)` preserves `bindHost`.
- Relaunch packaged Island with `zsh scripts/launch-packaged-app.sh`.
- Verify listener/auth manually:
  ```bash
  lsof -nP -iTCP:3079 -sTCP:LISTEN
  curl -i -X POST -H 'Content-Type: application/json' -d '{}' http://127.0.0.1:3079/api/health
  curl -o /dev/null -w '%{http_code}\n' -X POST \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{}' http://127.0.0.1:3079/api/health
  ```

### 7. Wrong vs Correct

#### Wrong

```swift
values["ARCHIPELAGO_HOST"] = "127.0.0.1"
var baseURL: URL { URL(string: "http://0.0.0.0:\(port)")! }
```

#### Correct

```swift
values["ARCHIPELAGO_HOST"] = bindHost
var baseURL: URL { URL(string: "http://127.0.0.1:\(port)")! }
```

---

## Scenario: Archipelago Server MCP Marketplace HTTP 403 Fallback

### 1. Scope / Trigger

- Trigger: Archipelago Server settings -> MCP market search returns `official MCP registry request failed: HTTP 403 Forbidden` or the same error for Smithery.
- Applies to `modules/collaboration-runtime/src-tauri/src/commands/mcp.rs` marketplace search/detail requests.
- This is a backend marketplace HTTP compatibility issue, not a frontend settings state issue.

### 2. Signatures

- Official search endpoint:
  ```text
  https://registry.modelcontextprotocol.io/v0.1/servers?limit={limit}&version=latest&search={query}
  ```
- Official detail endpoint:
  ```text
  https://registry.modelcontextprotocol.io/v0.1/servers/{server_name}/versions/latest
  ```
- Smithery search endpoint:
  ```text
  https://api.smithery.ai/servers?limit={limit}&q={query}
  ```
- Smithery detail endpoint:
  ```text
  https://api.smithery.ai/servers/{server_id}
  ```

### 3. Contracts

- `reqwest` remains the primary marketplace HTTP client.
- If `reqwest` receives HTTP 403 for a marketplace GET request, retry the exact encoded URL through `/usr/bin/curl` when present, otherwise `curl` on `PATH`.
- The curl fallback must:
  - use direct argv invocation, not a shell string,
  - set `User-Agent: archipelago-mcp-market/1.0`,
  - set `Accept: application/json`,
  - use `--fail --silent --show-error --location`,
  - keep the same timeout envelope as the primary client.
- The fallback is only for read-only marketplace GET JSON fetches. Do not use it for user data writes, local config mutation, or ACP chat requests.

### 4. Validation & Error Matrix

- `reqwest` success -> parse JSON from the primary response.
- `reqwest` HTTP 403 -> retry with curl fallback and parse JSON from stdout.
- `reqwest` HTTP 429 or 5xx -> preserve retry behavior from `send_request_with_retry`.
- curl missing or cannot start -> return `network_error` with `curl fallback failed to start`.
- curl exits non-zero -> return `network_error` with the curl status and stderr.
- curl returns non-UTF8 or invalid JSON -> return `network_error` with parse context.

### 5. Good/Base/Bad Cases

- Good: terminal `curl` can access the marketplace while app `reqwest` gets 403; Archipelago Server retries through curl and the settings page receives marketplace items.
- Base: `reqwest` works normally; curl is never launched.
- Bad: frontend hides the provider or only changes the default marketplace while backend detail/install requests still fail.
- Bad: invoking curl through a shell command with an interpolated URL.

### 6. Tests Required

- Run `cargo check --manifest-path modules/collaboration-runtime/src-tauri/Cargo.toml --bin archipelago-server --no-default-features` after changing the helper.
- Run `cargo test --manifest-path modules/collaboration-runtime/src-tauri/Cargo.toml --lib mcp --no-default-features`.
- Rebuild release helpers with `cargo build --release --bin archipelago-server --bin archipelago-mcp --no-default-features`.
- Relaunch packaged Archipelago with `zsh scripts/launch-packaged-app.sh`; `ARCHIPELAGO_RUNTIME_SKIP_BUILD=true` reuses release helpers, so do not skip the release helper rebuild after Rust backend changes.
- Verify local API calls return HTTP 200:
  ```bash
  curl -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"providerId":"official_registry","query":"filesystem","limit":5}' \
    http://127.0.0.1:3079/api/mcp_search_marketplace
  ```

### 7. Wrong vs Correct

#### Wrong

```rust
if !response.status().is_success() {
    return Err(mcp_network(format!(
        "official MCP registry request failed: HTTP {}",
        response.status()
    )));
}
```

#### Correct

```rust
fetch_marketplace_json(
    "failed to query official MCP registry",
    "official MCP registry request failed",
    "failed to parse official MCP registry response",
    &url,
    || client.get(url.clone()),
)
.await
```
