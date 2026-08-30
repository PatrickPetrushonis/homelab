#!/usr/bin/env bash
set -euo pipefail

# Lints this repo's own scripts/, then delegates to each submodule's
# own lint.sh if it has one. Does not scan submodule files directly -
# each submodule owns its own lint.sh and decides what "clean" means
# for itself; this script only orchestrates, matching the same
# foreach-across-submodules pattern submodule_ctl.sh already uses.
#
# Usage:  ./scripts/lint.sh
#
# Exits non-zero if anything failed, anywhere.

require() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found on PATH" >&2; exit 1; }; }
require git

if ! command -v shellcheck &>/dev/null; then
    echo "shellcheck not found — installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y shellcheck
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

FAILED=0

echo "=== homelab (parent, own scripts/) ==="
mapfile -t OWN_SCRIPTS < <(find "$SCRIPT_DIR" -name '*.sh' | sort)
for f in "${OWN_SCRIPTS[@]}"; do
    file_dir="$(dirname "$f")"
    file_base="$(basename "$f")"
    if ( cd "$file_dir" && shellcheck -x "$file_base" ); then
        echo "  clean: $(basename "$f")"
    else
        FAILED=$(( FAILED + 1 ))
    fi
done
echo ""

for sub in llm nas system plex; do
    echo "=== ${sub} ==="
    lint_path="${REPO_ROOT}/${sub}/scripts/lint.sh"
    if [[ -x "$lint_path" ]]; then
        if ( cd "${REPO_ROOT}/${sub}" && ./scripts/lint.sh ); then
            :
        else
            FAILED=$(( FAILED + 1 ))
        fi
    else
        echo "  no executable scripts/lint.sh in ${sub} - skipping"
    fi
    echo ""
done

echo "------------------------------------------"
if [[ $FAILED -eq 0 ]]; then
    echo "All repos clean (or had nothing to lint)."
else
    echo "$FAILED repo(s) had findings or failures — see above."
fi
exit "$FAILED"