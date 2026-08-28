#!/usr/bin/env bash
set -euo pipefail

# Splits llm/, nas/, system/, and plex/ (renamed from video-encoder/) out of
# the homelab repo into their own standalone repos with history preserved,
# then re-adds each as a git submodule pointing at its new remote.
#
# PREREQUISITES:
#   - git filter-repo installed (pip install git-filter-repo, or apt/brew)
#   - four EMPTY remote repos already created (GitHub/GitLab/etc) - this
#     script pushes to them, it does not create them
#   - run from either inside homelab/ or its parent directory - detected
#     automatically below
#
# Fill in the four remote URLs below before running. Run once - re-running
# after the parent repo has been modified will re-filter stale state.

require() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found on PATH" >&2; exit 1; }; }
require git
require git-filter-repo

# Works whether invoked from inside homelab/ (this script's actual location)
# or from its parent directory. Resolves to absolute paths so the temp
# work dir is always a sibling of homelab, never nested inside it.
if [[ -d "./.git" ]]; then
    HOMELAB_DIR="$(pwd)"
elif [[ -d "./homelab/.git" ]]; then
    HOMELAB_DIR="$(cd ./homelab && pwd)"
else
    echo "ERROR: could not find homelab repo. Run this from inside homelab/ or its parent directory." >&2
    exit 1
fi

WORK_DIR="$(dirname "$HOMELAB_DIR")/_submodule_split_work"

# --- Actual remotes ---
declare -A REMOTES=(
    [llm]="git@github.com:PatrickPetrushonis/llm.git"
    [nas]="git@github.com:PatrickPetrushonis/nas.git"
    [system]="git@github.com:PatrickPetrushonis/system.git"
    [plex]="git@github.com:PatrickPetrushonis/plex.git"
)
# video-encoder/ is renamed to plex/ as part of this split, not before it -
# the rename happens inside the filtered clone, so parent history for that
# directory is preserved under its old name up to this point.
declare -A SOURCE_DIRS=(
    [llm]="llm"
    [nas]="nas"
    [system]="system"
    [plex]="video-encoder"
)

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

for name in "${!REMOTES[@]}"; do
    remote="${REMOTES[$name]}"
    src_dir="${SOURCE_DIRS[$name]}"
    split_path="$WORK_DIR/$name"

    echo "=== Splitting ${src_dir}/ -> ${name} ==="

    git clone "$HOMELAB_DIR" "$split_path"
    (
        cd "$split_path"
        git filter-repo --path "$src_dir/" --path-rename "$src_dir/:"
        git remote add origin "$remote"
        git branch -M main
        git push -u origin main
    )

    echo "=== Removing ${src_dir}/ from homelab and adding as submodule ${name} ==="
    (
        cd "$HOMELAB_DIR"
        git rm -r --quiet "$src_dir"
        git submodule add -b main "$remote" "$name"
        git config -f .gitmodules "submodule.${name}.branch" main
    )

    echo "=== ${name} done ==="
    echo
done

(
    cd "$HOMELAB_DIR"
    git add .gitmodules
    git commit -m "Split llm, nas, system, plex into submodules"
)

echo "All four splits complete. Review 'git status' and '.gitmodules' inside homelab/ before pushing."
echo "Cleanup: rm -rf ${WORK_DIR}"