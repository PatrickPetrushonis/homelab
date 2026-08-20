#!/usr/bin/env bash
# Run this SECOND, after reviewing rename_dry.sh's output.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

: "${DOWNLOADS_BASE:=$HOME/Downloads}"

INPUT_DIR="$DOWNLOADS_BASE/Complete"
OUTPUT_DIR="$DOWNLOADS_BASE/Logs"

./rename_plex.sh -O "$OUTPUT_DIR" "$INPUT_DIR"