#!/usr/bin/env bash
# Run this FIRST. Preview only — nothing is renamed.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

./rename_plex.sh -n "$INPUT_DIR"