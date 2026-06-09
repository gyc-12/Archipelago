#!/bin/zsh

set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "Archipelago packaged launch runs only on macOS." >&2
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
package_root="$(env_or_default ARCHIPELAGO_PACKAGE_ROOT "$repo_root/output/package")"
bundle_dir="$(env_or_default ARCHIPELAGO_BUNDLE_DIR "$package_root/$app_name.app")"

cd "$repo_root"

# This is the current manual-test launch path for the integrated Archipelago app.
# It intentionally uses the production-style packaged bundle, not the dev app path.
ARCHIPELAGO_RUNTIME_SKIP_BUILD="$(env_or_default ARCHIPELAGO_RUNTIME_SKIP_BUILD "true")" \
ARCHIPELAGO_SKIP_BRAND_GENERATION="$(env_or_default ARCHIPELAGO_SKIP_BRAND_GENERATION "true")" \
ARCHIPELAGO_SKIP_DMG="$(env_or_default ARCHIPELAGO_SKIP_DMG "true")" \
    zsh scripts/package-app.sh

if [[ ! -d "$bundle_dir" ]]; then
    echo "Packaged app missing after package step: $bundle_dir" >&2
    exit 1
fi

osascript -e 'tell application "Archipelago" to quit' 2>/dev/null || true
# Also stop legacy dev bundles that may still be running on this machine.
osascript -e 'tell application "Open Island Dev" to quit' 2>/dev/null || true
osascript -e 'tell application "Open Island" to quit' 2>/dev/null || true
pkill -f "Archipelago|Open Island Dev|ArchipelagoApp" 2>/dev/null || true

open -n "$bundle_dir"

echo "Launched packaged app: $bundle_dir"
