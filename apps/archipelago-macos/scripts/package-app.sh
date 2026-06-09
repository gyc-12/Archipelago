#!/bin/zsh

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Archipelago packaging runs only on macOS." >&2
    exit 1
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

env_or_default() {
    local primary="$1"
    local default_value="$2"
    if [[ -n "${(P)primary:-}" ]]; then
        print -r -- "${(P)primary}"
    else
        print -r -- "$default_value"
    fi
}

app_name="$(env_or_default ARCHIPELAGO_APP_NAME "Archipelago")"
bundle_identifier="$(env_or_default ARCHIPELAGO_BUNDLE_ID "app.archipelago.dev")"
version="$(env_or_default ARCHIPELAGO_VERSION "0.0.1")"
build_number="$(env_or_default ARCHIPELAGO_BUILD_NUMBER "$(git -C "$repo_root" rev-list --count HEAD 2>/dev/null || echo 1)")"
package_root="$(env_or_default ARCHIPELAGO_PACKAGE_ROOT "$repo_root/output/package")"
bundle_dir="$(env_or_default ARCHIPELAGO_BUNDLE_DIR "$package_root/$app_name.app")"
zip_path="$(env_or_default ARCHIPELAGO_ZIP_PATH "$package_root/$app_name.zip")"
dmg_path="$(env_or_default ARCHIPELAGO_DMG_PATH "$package_root/$app_name.dmg")"
signing_identity="$(env_or_default ARCHIPELAGO_SIGN_IDENTITY "")"
notary_profile="$(env_or_default ARCHIPELAGO_NOTARY_PROFILE "")"
runtime_root="$(env_or_default ARCHIPELAGO_RUNTIME_ROOT "$repo_root/../../modules/collaboration-runtime")"
runtime_static_dir="$(env_or_default ARCHIPELAGO_RUNTIME_WEB_DIR "$runtime_root/out")"
runtime_server_binary="$(env_or_default ARCHIPELAGO_RUNTIME_SERVER_BINARY "$runtime_root/src-tauri/target/release/archipelago-server")"
runtime_mcp_binary="$(env_or_default ARCHIPELAGO_RUNTIME_MCP_BINARY "$runtime_root/src-tauri/target/release/archipelago-mcp")"
runtime_skip_build="$(env_or_default ARCHIPELAGO_RUNTIME_SKIP_BUILD "false")"
skip_brand_generation="$(env_or_default ARCHIPELAGO_SKIP_BRAND_GENERATION "false")"
skip_dmg="$(env_or_default ARCHIPELAGO_SKIP_DMG "false")"

brand_script="$repo_root/scripts/generate_brand_icons.py"
dmg_bg_script="$repo_root/scripts/generate_dmg_background.py"
entitlements_path="$repo_root/config/packaging/ArchipelagoApp.entitlements"

cd "$repo_root"

arch_flags=()
universal_build="$(env_or_default ARCHIPELAGO_UNIVERSAL "false")"
if [[ "$universal_build" == "true" ]]; then
    arch_flags=(--arch arm64 --arch x86_64)
    if [[ "$runtime_skip_build" != "true" ]]; then
        echo "ERROR: ARCHIPELAGO_UNIVERSAL=true requires prebuilt universal runtime helper binaries." >&2
        echo "       Set ARCHIPELAGO_RUNTIME_SKIP_BUILD=true and provide ARCHIPELAGO_RUNTIME_SERVER_BINARY / ARCHIPELAGO_RUNTIME_MCP_BINARY." >&2
        exit 1
    fi
fi

swift build -c release "${arch_flags[@]}" --product ArchipelagoApp
swift build -c release "${arch_flags[@]}" --product ArchipelagoHooks
swift build -c release "${arch_flags[@]}" --product ArchipelagoSetup

if [[ "$runtime_skip_build" != "true" ]]; then
    if [[ ! -d "$runtime_root" ]]; then
        echo "ERROR: collaboration runtime root not found at $runtime_root. Set ARCHIPELAGO_RUNTIME_ROOT to override." >&2
        exit 1
    fi
    if ! command -v pnpm >/dev/null 2>&1; then
        echo "ERROR: pnpm is required to build collaboration runtime web assets." >&2
        exit 1
    fi
    if ! command -v cargo >/dev/null 2>&1; then
        echo "ERROR: cargo is required to build collaboration runtime helper binaries." >&2
        exit 1
    fi

    (cd "$runtime_root" && pnpm build)
    (cd "$runtime_root/src-tauri" && cargo build --release --bin archipelago-server --bin archipelago-mcp --no-default-features)
fi

build_bin_dir="$(swift build -c release "${arch_flags[@]}" --show-bin-path)"
app_binary="$build_bin_dir/ArchipelagoApp"
hooks_binary="$build_bin_dir/ArchipelagoHooks"
setup_binary="$build_bin_dir/ArchipelagoSetup"
brand_icon="$repo_root/Assets/Brand/Archipelago.icns"

if [[ "$skip_brand_generation" != "true" ]]; then
    python3 "$brand_script"
    python3 "$dmg_bg_script"
elif [[ ! -f "$brand_icon" || ! -f "$repo_root/Assets/Brand/dmg-background@2x.png" ]]; then
    echo "ERROR: ARCHIPELAGO_SKIP_BRAND_GENERATION=true requires existing brand icon and DMG background assets." >&2
    exit 1
fi

rm -rf "$bundle_dir" "$zip_path" "$dmg_path"
mkdir -p "$bundle_dir/Contents/MacOS" "$bundle_dir/Contents/Helpers" "$bundle_dir/Contents/Resources" "$bundle_dir/Contents/Frameworks"

cp "$app_binary" "$bundle_dir/Contents/MacOS/ArchipelagoApp"
cp "$hooks_binary" "$bundle_dir/Contents/Helpers/ArchipelagoHooks"
cp "$setup_binary" "$bundle_dir/Contents/Helpers/ArchipelagoSetup"
cp "$brand_icon" "$bundle_dir/Contents/Resources/Archipelago.icns"

if [[ ! -x "$runtime_server_binary" ]]; then
    echo "ERROR: archipelago-server binary not found or not executable at $runtime_server_binary." >&2
    exit 1
fi
if [[ ! -x "$runtime_mcp_binary" ]]; then
    echo "ERROR: archipelago-mcp binary not found or not executable at $runtime_mcp_binary." >&2
    exit 1
fi
if [[ ! -f "$runtime_static_dir/index.html" ]]; then
    echo "ERROR: collaboration runtime static export not found at $runtime_static_dir/index.html." >&2
    exit 1
fi

cp "$runtime_server_binary" "$bundle_dir/Contents/Helpers/archipelago-server"
cp "$runtime_mcp_binary" "$bundle_dir/Contents/Helpers/archipelago-mcp"
cp -R "$runtime_static_dir" "$bundle_dir/Contents/Resources/ArchipelagoWeb"

# Copy Sparkle.framework for auto-update support.
sparkle_framework="$repo_root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ -d "$sparkle_framework" ]]; then
    cp -R "$sparkle_framework" "$bundle_dir/Contents/Frameworks/"
else
    echo "WARNING: Sparkle.framework not found at $sparkle_framework — run 'swift package resolve' first." >&2
fi

# Copy SPM resource bundle into Contents/Resources/ so the .app root stays
# clean for code signing (no unsealed contents). Our custom
# resource_bundle_accessor.swift searches Bundle.main.resourceURL first.
spm_resource_bundle="$build_bin_dir/Archipelago_ArchipelagoApp.bundle"
if [[ -d "$spm_resource_bundle" ]]; then
    cp -R "$spm_resource_bundle" "$bundle_dir/Contents/Resources/"
    find "$bundle_dir/Contents/Resources/Archipelago_ArchipelagoApp.bundle" \
        -maxdepth 1 \
        -type f \
        -name "*opencode.js" \
        ! -name "archipelago-opencode.js" \
        -delete
else
    echo "WARNING: SPM resource bundle not found at $spm_resource_bundle — app may crash on launch." >&2
fi

chmod +x \
    "$bundle_dir/Contents/MacOS/ArchipelagoApp" \
    "$bundle_dir/Contents/Helpers/ArchipelagoHooks" \
    "$bundle_dir/Contents/Helpers/ArchipelagoSetup" \
    "$bundle_dir/Contents/Helpers/archipelago-server" \
    "$bundle_dir/Contents/Helpers/archipelago-mcp"

# Add rpath so the binary can find Sparkle.framework in Contents/Frameworks/.
install_name_tool -add_rpath @loader_path/../Frameworks "$bundle_dir/Contents/MacOS/ArchipelagoApp" 2>/dev/null || true

cat > "$bundle_dir/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleDisplayName</key>
    <string>$app_name</string>
    <key>CFBundleExecutable</key>
    <string>ArchipelagoApp</string>
    <key>CFBundleIconFile</key>
    <string>Archipelago</string>
    <key>CFBundleIdentifier</key>
    <string>$bundle_identifier</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$app_name</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$version</string>
    <key>CFBundleVersion</key>
    <string>$build_number</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Archipelago needs automation access to focus Terminal and iTerm sessions for jump-back.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SUFeedURL</key>
    <string>${ARCHIPELAGO_APPCAST_URL:-}</string>
    <key>SUPublicEDKey</key>
    <string>$(env_or_default ARCHIPELAGO_EDDSA_PUBLIC_KEY "3IF8txq9RRNanzE2FNhyGRcwhslTucCcJHpTkpxcgBQ=")</string>
</dict>
</plist>
EOF

plutil -lint "$bundle_dir/Contents/Info.plist" >/dev/null

# --- Verify bundle structure matches what the app expects at runtime ---
verify_errors=0
for required in \
    "Contents/MacOS/ArchipelagoApp" \
    "Contents/Helpers/ArchipelagoHooks" \
    "Contents/Helpers/ArchipelagoSetup" \
    "Contents/Helpers/archipelago-server" \
    "Contents/Helpers/archipelago-mcp" \
    "Contents/Resources/Archipelago.icns" \
    "Contents/Resources/ArchipelagoWeb/index.html" \
    "Contents/Resources/Archipelago_ArchipelagoApp.bundle" \
    "Contents/Resources/Archipelago_ArchipelagoApp.bundle/archipelago-opencode.js" \
; do
    if [[ ! -e "$bundle_dir/$required" ]]; then
        echo "ERROR: missing required file: $required" >&2
        verify_errors=$((verify_errors + 1))
    fi
done

if [[ $verify_errors -gt 0 ]]; then
    echo "Bundle verification failed with $verify_errors error(s)." >&2
    exit 1
fi
echo "Bundle structure verified."

# --- Smoke-test the app outside the repo to catch Bundle.module fallback hacks ---
# SPM's generated resource accessor has a hardcoded fallback to the local .build/
# directory. Running from /tmp ensures the app works without that crutch.
smoke_dir="$(mktemp -d)/smoke-test"
mkdir -p "$smoke_dir"
cp -R "$bundle_dir" "$smoke_dir/"
smoke_app="$smoke_dir/$(basename "$bundle_dir")"
smoke_binary="$smoke_app/Contents/MacOS/ArchipelagoApp"
smoke_archipelago_server="$smoke_app/Contents/Helpers/archipelago-server"
if [[ -x "$smoke_binary" ]]; then
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: python3 is required for packaged app smoke verification." >&2
        exit 1
    fi

    smoke_root="$(dirname "$smoke_dir")"
    smoke_workspace="$smoke_root/workspace"
    smoke_data_dir="$smoke_root/archipelago-data"
    smoke_state="$smoke_root/smoke-state.json"
    smoke_token="archipelago-smoke-$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-')"
    smoke_port="$(python3 - <<'PY'
import socket

with socket.socket() as sock:
    sock.bind(("127.0.0.1", 0))
    print(sock.getsockname()[1])
PY
)"
    smoke_pid=""
    mkdir -p "$smoke_workspace" "$smoke_data_dir"

    cleanup_smoke() {
        if [[ -n "${smoke_pid:-}" ]] && kill -0 "$smoke_pid" 2>/dev/null; then
            kill "$smoke_pid" 2>/dev/null || true
            wait "$smoke_pid" 2>/dev/null || true
        fi
        if [[ -x "$smoke_archipelago_server" ]]; then
            pkill -f "$smoke_archipelago_server" 2>/dev/null || true
        fi
        rm -rf "$smoke_root"
    }
    trap cleanup_smoke EXIT

    launch_smoke_app() {
        ARCHIPELAGO_SERVER_PORT="$smoke_port" \
            ARCHIPELAGO_SERVER_TOKEN="$smoke_token" \
            ARCHIPELAGO_SERVER_DATA_DIR="$smoke_data_dir" \
            "$smoke_binary" &
        smoke_pid=$!
        sleep 1
        if ! kill -0 "$smoke_pid" 2>/dev/null; then
            wait "$smoke_pid" 2>/dev/null || true
            echo "ERROR: app crashed when launched outside the repo directory." >&2
            echo "       This likely means Bundle.module cannot find its resource bundle." >&2
            exit 1
        fi
    }

    stop_smoke_app() {
        if [[ -n "${smoke_pid:-}" ]] && kill -0 "$smoke_pid" 2>/dev/null; then
            kill "$smoke_pid" 2>/dev/null || true
            wait "$smoke_pid" 2>/dev/null || true
        fi
        smoke_pid=""
        if [[ -x "$smoke_archipelago_server" ]]; then
            pkill -f "$smoke_archipelago_server" 2>/dev/null || true
        fi
        sleep 1
    }

    launch_smoke_app
    python3 - "$smoke_port" "$smoke_token" "$smoke_workspace" "$smoke_state" <<'PY'
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

port, token, workspace, state_path = sys.argv[1:]
base = f"http://127.0.0.1:{port}"
title = "Archipelago package smoke"


def request(method, path, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(f"{base}{path}", data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=5) as response:
        return response.status, response.read()


def post(path, body):
    status, payload = request("POST", path, body)
    if not 200 <= status < 300:
        raise RuntimeError(f"{path} returned HTTP {status}")
    return json.loads(payload.decode("utf-8"))


def wait_for_health():
    deadline = time.time() + 25
    last_error = None
    while time.time() < deadline:
        try:
            status, _ = request("POST", "/api/health", {})
            if 200 <= status < 300:
                return
        except Exception as error:
            last_error = error
        time.sleep(0.5)
    raise RuntimeError(f"embedded Archipelago Server health check failed: {last_error}")


wait_for_health()
folder = post("/api/open_folder", {"path": workspace})
folder_id = folder.get("id")
if not isinstance(folder_id, int) or folder.get("path") != workspace:
    raise RuntimeError(f"open_folder returned unexpected payload: {folder!r}")

conversation_id = post(
    "/api/create_conversation",
    {"folderId": folder_id, "agentType": "codex", "title": title},
)
if not isinstance(conversation_id, int):
    raise RuntimeError(f"create_conversation returned unexpected payload: {conversation_id!r}")

conversations = post(
    "/api/list_all_conversations",
    {"folderIds": [folder_id], "agentType": "codex", "includeChildren": True},
)
if not any(item.get("id") == conversation_id and item.get("title") == title for item in conversations):
    raise RuntimeError(f"created conversation missing from list_all_conversations: {conversations!r}")

workspace_path = (
    "/workspace?"
    + urllib.parse.urlencode({
        "folderId": folder_id,
        "conversationId": conversation_id,
        "agent": "codex",
    })
)
_, html = request("GET", workspace_path)
if b"__next" not in html and b"archipelago" not in html.lower():
    raise RuntimeError("workspace route did not return the packaged Archipelago Web UI")

with open(state_path, "w", encoding="utf-8") as handle:
    json.dump(
        {
            "folder_id": folder_id,
            "conversation_id": conversation_id,
            "workspace": workspace,
            "title": title,
        },
        handle,
    )
PY

    stop_smoke_app
    launch_smoke_app
    python3 - "$smoke_port" "$smoke_token" "$smoke_state" <<'PY'
import json
import sys
import time
import urllib.request

port, token, state_path = sys.argv[1:]
base = f"http://127.0.0.1:{port}"
with open(state_path, "r", encoding="utf-8") as handle:
    state = json.load(handle)


def request(method, path, body=None):
    data = None if body is None else json.dumps(body).encode("utf-8")
    req = urllib.request.Request(f"{base}{path}", data=data, method=method)
    req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Content-Type", "application/json")
    with urllib.request.urlopen(req, timeout=5) as response:
        return response.status, response.read()


def post(path, body):
    status, payload = request("POST", path, body)
    if not 200 <= status < 300:
        raise RuntimeError(f"{path} returned HTTP {status}")
    return json.loads(payload.decode("utf-8"))


def wait_for_health():
    deadline = time.time() + 25
    last_error = None
    while time.time() < deadline:
        try:
            status, _ = request("POST", "/api/health", {})
            if 200 <= status < 300:
                return
        except Exception as error:
            last_error = error
        time.sleep(0.5)
    raise RuntimeError(f"embedded Archipelago Server restart health check failed: {last_error}")


wait_for_health()
folders = post("/api/list_open_folder_details", {})
if not any(item.get("id") == state["folder_id"] and item.get("path") == state["workspace"] for item in folders):
    raise RuntimeError(f"created folder did not persist after restart: {folders!r}")

conversations = post(
    "/api/list_all_conversations",
    {"folderIds": [state["folder_id"]], "agentType": "codex", "includeChildren": True},
)
if not any(
    item.get("id") == state["conversation_id"] and item.get("title") == state["title"]
    for item in conversations
):
    raise RuntimeError(f"created conversation did not persist after restart: {conversations!r}")
PY

    stop_smoke_app
    cleanup_smoke
    trap - EXIT
    echo "Smoke test passed — packaged app launched embedded collaboration runtime, created a conversation, served workspace, and preserved data across restart."
else
    echo "WARNING: smoke test skipped — binary not found at $smoke_binary" >&2
fi

sparkle_fw="$bundle_dir/Contents/Frameworks/Sparkle.framework"

if [[ -n "$signing_identity" ]]; then
    # Sign nested code objects inside-out: Sparkle internals → helpers → app.

    if [[ -d "$sparkle_fw" ]]; then
        for xpc in "$sparkle_fw"/Versions/B/XPCServices/*.xpc; do
            [[ -d "$xpc" ]] && codesign --force --options runtime --timestamp --sign "$signing_identity" "$xpc"
        done
        [[ -f "$sparkle_fw/Versions/B/Autoupdate" ]] && \
            codesign --force --options runtime --timestamp --sign "$signing_identity" "$sparkle_fw/Versions/B/Autoupdate"
        [[ -d "$sparkle_fw/Versions/B/Updater.app" ]] && \
            codesign --force --options runtime --timestamp --sign "$signing_identity" "$sparkle_fw/Versions/B/Updater.app"
        codesign --force --options runtime --timestamp --sign "$signing_identity" "$sparkle_fw"
    fi

    codesign --force --options runtime --timestamp --sign "$signing_identity" \
        "$bundle_dir/Contents/Helpers/ArchipelagoHooks"
    codesign --force --options runtime --timestamp --sign "$signing_identity" \
        "$bundle_dir/Contents/Helpers/ArchipelagoSetup"
    codesign --force --options runtime --timestamp --sign "$signing_identity" \
        "$bundle_dir/Contents/Helpers/archipelago-server"
    codesign --force --options runtime --timestamp --sign "$signing_identity" \
        "$bundle_dir/Contents/Helpers/archipelago-mcp"

    codesign \
        --force \
        --options runtime \
        --timestamp \
        --entitlements "$entitlements_path" \
        --sign "$signing_identity" \
        "$bundle_dir"

    codesign --verify --deep --strict --verbose=2 "$bundle_dir"
else
    # Ad-hoc sign so macOS accepts the embedded Sparkle.framework.
    if [[ -d "$sparkle_fw" ]]; then
        for xpc in "$sparkle_fw"/Versions/B/XPCServices/*.xpc; do
            [[ -d "$xpc" ]] && codesign --force --sign - "$xpc" 2>/dev/null || true
        done
        codesign --force --sign - "$sparkle_fw" 2>/dev/null || true
    fi
    codesign --force --sign - "$bundle_dir/Contents/Helpers/ArchipelagoHooks" 2>/dev/null || true
    codesign --force --sign - "$bundle_dir/Contents/Helpers/ArchipelagoSetup" 2>/dev/null || true
    codesign --force --sign - "$bundle_dir/Contents/Helpers/archipelago-server" 2>/dev/null || true
    codesign --force --sign - "$bundle_dir/Contents/Helpers/archipelago-mcp" 2>/dev/null || true
    codesign --force --sign - "$bundle_dir" 2>/dev/null || true
fi

ditto -c -k --keepParent "$bundle_dir" "$zip_path"

# --- Notarize app bundle (before DMG so the stapled bundle goes into the DMG) ---
if [[ -n "$signing_identity" && -n "$notary_profile" ]]; then
    xcrun notarytool submit "$zip_path" --keychain-profile "$notary_profile" --wait
    xcrun stapler staple -v "$bundle_dir"
    rm -f "$zip_path"
    ditto -c -k --keepParent "$bundle_dir" "$zip_path"
fi

if [[ "$skip_dmg" != "true" ]]; then
    if ! command -v create-dmg >/dev/null 2>&1; then
        echo "ERROR: create-dmg is required to build the DMG. Set ARCHIPELAGO_SKIP_DMG=true to create only the app bundle and zip." >&2
        exit 1
    fi

    # --- Styled DMG creation ---
    dmg_bg="$repo_root/Assets/Brand/dmg-background@2x.png"

    create-dmg \
        --volname "$app_name" \
        --background "$dmg_bg" \
        --window-pos 200 120 \
        --window-size 660 400 \
        --icon-size 96 \
        --text-size 13 \
        --icon "$app_name.app" 180 210 \
        --hide-extension "$app_name.app" \
        --app-drop-link 480 210 \
        --no-internet-enable \
        "$dmg_path" \
        "$bundle_dir"

    # Sign the DMG itself (required before notarization)
    if [[ -n "$signing_identity" ]]; then
        codesign \
            --force \
            --sign "$signing_identity" \
            --timestamp \
            "$dmg_path"
    fi

    # Notarize and staple the DMG
    if [[ -n "$signing_identity" && -n "$notary_profile" ]]; then
        xcrun notarytool submit "$dmg_path" --keychain-profile "$notary_profile" --wait
        xcrun stapler staple -v "$dmg_path"
    fi
fi

echo "Bundle: $bundle_dir"
echo "Archive: $zip_path"
if [[ "$skip_dmg" != "true" ]]; then
    echo "DMG: $dmg_path"
fi
if [[ -n "$signing_identity" ]]; then
    echo "Signed with identity: $signing_identity"
else
    echo "No signing identity configured; produced an unsigned local bundle."
fi

if [[ -n "$notary_profile" ]]; then
    echo "Notary profile: $notary_profile"
fi
