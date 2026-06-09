#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"

if (( $# == 0 )); then
    steps=(lint test build)
else
    steps=("$@")
fi

run_step() {
    local step="$1"

    case "$step" in
        test)
            echo "==> test"
            swift test
            ;;
        lint)
            echo "==> lint"
            zsh "$repo_root/scripts/lint-strings.sh"
            ;;
        build)
            echo "==> build"
            swift build
            ;;
        smoke)
            echo "==> smoke"
            ARCHIPELAGO_RUNTIME_SKIP_BUILD="${ARCHIPELAGO_RUNTIME_SKIP_BUILD:-true}" \
            ARCHIPELAGO_SKIP_BRAND_GENERATION="${ARCHIPELAGO_SKIP_BRAND_GENERATION:-true}" \
            ARCHIPELAGO_SKIP_DMG="${ARCHIPELAGO_SKIP_DMG:-true}" \
                zsh "$repo_root/scripts/package-app.sh"
            ;;
        ci)
            run_step lint
            run_step test
            run_step build
            ;;
        all)
            run_step lint
            run_step test
            run_step build
            run_step smoke
            ;;
        *)
            echo "usage: scripts/harness.sh [lint|test|build|smoke|ci|all] ..." >&2
            exit 64
            ;;
    esac
}

for step in "${steps[@]}"; do
    run_step "$step"
done
