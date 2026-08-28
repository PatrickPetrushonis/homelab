#!/usr/bin/env bash
set -euo pipefail

# Routine operations across all submodules. Run from the homelab root.
#
# Usage:
#   ./submodule_ctl.sh status              # what's changed, anywhere
#   ./submodule_ctl.sh update-all           # pull latest main in every submodule
#   ./submodule_ctl.sh checkout-branches    # fix detached HEAD in every submodule
#   ./submodule_ctl.sh bump <name>          # commit the parent's pointer to a submodule's current commit

require() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found on PATH" >&2; exit 1; }; }
require git

if [[ ! -f .gitmodules ]]; then
    echo "ERROR: no .gitmodules here. Run this from the homelab root." >&2
    exit 1
fi

cmd="${1:-}"

case "$cmd" in
    status)
        git submodule foreach 'echo "--- $name ---"; git status --short --branch'
        ;;
    update-all)
        git submodule foreach 'git checkout main 2>/dev/null || true; git pull origin main'
        echo "Submodules updated locally. Run 'git add <name>' per changed submodule, then commit to bump the parent's pointer."
        ;;
    checkout-branches)
        # Submodules land in detached HEAD after clone/update by default -
        # this is expected git behavior, not a bug, but editing in that
        # state is a mistake waiting to happen.
        git submodule foreach 'git checkout main 2>/dev/null || echo "  (no main branch in $name - check manually)"'
        ;;
    bump)
        name="${2:-}"
        if [[ -z "$name" ]]; then
            echo "Usage: $0 bump <submodule-name>" >&2
            exit 1
        fi
        if [[ ! -d "$name" ]]; then
            echo "ERROR: no submodule at ./${name}" >&2
            exit 1
        fi
        git add "$name"
        git commit -m "Bump ${name} submodule"
        echo "Bumped and committed. Push the parent repo to publish."
        ;;
    *)
        echo "Usage: $0 {status|update-all|checkout-branches|bump <name>}" >&2
        exit 1
        ;;
esac