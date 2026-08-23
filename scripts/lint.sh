#!/usr/bin/env bash
# lint.sh: Runs shellcheck against every script in this repo, installing
# the tool itself via apt first if it isn't already present.
#
# Usage:  ./lint.sh
#
# Exits non-zero if shellcheck finds anything, so it's usable as a
# pre-commit gate later if wanted — not wired up as one yet, this is
# just the standalone runner.

set -euo pipefail

if ! command -v shellcheck &>/dev/null; then
    echo "shellcheck not found — installing via apt..."
    sudo apt-get update -qq
    sudo apt-get install -y shellcheck
fi

echo "shellcheck $(shellcheck --version | grep version:)"
echo ""

# Every .sh file in the repo, wherever it ends up after restructuring —
# not a hardcoded list, so this doesn't need editing when files move.
mapfile -t SCRIPTS < <(find . -name '*.sh' -not -path './.git/*' | sort)

if [[ ${#SCRIPTS[@]} -eq 0 ]]; then
    echo "No .sh files found."
    exit 0
fi

echo "Checking ${#SCRIPTS[@]} script(s):"
printf '  %s\n' "${SCRIPTS[@]}"
echo ""

FAILED=0
for f in "${SCRIPTS[@]}"; do
    echo "=== $f ==="
    # -x: follow sourced files (config.sh, lang_table.sh) so shellcheck can
    # actually resolve them instead of just emitting SC1091 about not
    # following. The `# shellcheck source=./config.sh`-style directives in
    # those files tell it where to look when the source path is dynamic.
    # Run from inside the file's own directory (not lint.sh's cwd): a
    # relative source like "./config.sh" resolves against shellcheck's
    # current directory, not the checked file's location, so checking
    # "./scripts/foo.sh" from the repo root would otherwise have shellcheck
    # look for "./config.sh" at the repo root instead of scripts/config.sh.
    file_dir="$(dirname "$f")"
    file_base="$(basename "$f")"
    if ( cd "$file_dir" && shellcheck -x "$file_base" ); then
        echo "  clean"
    else
        FAILED=$(( FAILED + 1 ))
    fi
    echo ""
done

echo "------------------------------------------"
if [[ $FAILED -eq 0 ]]; then
    echo "All ${#SCRIPTS[@]} scripts clean."
else
    echo "$FAILED of ${#SCRIPTS[@]} script(s) have findings — see above."
fi

exit "$FAILED"