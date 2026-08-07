#!/usr/bin/env bash
# shared by encode_dry.sh and encode.sh. Source, don't run directly.

: "${VIDEOS_BASE:=$HOME/Videos}"

INPUT_DIR="$VIDEOS_BASE/input"
OUTPUT_DIR="$VIDEOS_BASE/output"
ARCHIVE_DIR="$VIDEOS_BASE/encoded"
BACKUP_DIR="$VIDEOS_BASE/backup"

CRF="${CRF:-22}"
PRESET="${PRESET:-fast}"

ENCODER_ARGS=(-r -s -c "$CRF" -p "$PRESET" -o "$OUTPUT_DIR" -M "$ARCHIVE_DIR" -A "$BACKUP_DIR")

# ── Caller-side concurrency lock ──────────────────────────────────────────────
# encoder_params.sh itself has no internal lock, so two wrapper runs against
# the same OUTPUT_DIR can race on the same .tmp output file and the same .txt log. 

# Enforced here instead of editing the project script. 
# Exclusive, non-blocking; released automatically when the wrapper exits (fd 9 closes). 
acquire_output_lock() {
    mkdir -p "$OUTPUT_DIR"
    local lock_file="$OUTPUT_DIR/.encoder.lock"
    exec 9>"$lock_file"
    if ! flock -n 9; then
        echo "ERROR: another run is already active against $OUTPUT_DIR (lock: $lock_file)" >&2
        exit 1
    fi
}