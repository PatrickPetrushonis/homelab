#!/usr/bin/env bash
# config.sh — shared by encoder_dry.sh, encoder.sh, rename_dry.sh, and rename.sh. 
# Source, don't run directly. Override any value at call time:
#   VIDEOS_BASE=/mnt/scratch/Videos ./encoder.sh

: "${VIDEOS_BASE:=$HOME/Videos}"

INPUT_DIR="$VIDEOS_BASE/input"
OUTPUT_DIR="$VIDEOS_BASE/output"
ARCHIVE_DIR="$VIDEOS_BASE/encoded"
BACKUP_DIR="$VIDEOS_BASE/backup"

CRF="${CRF:-22}"
PRESET="${PRESET:-fast}"

ENCODER_ARGS=(-r -s -c "$CRF" -p "$PRESET" -o "$OUTPUT_DIR" -M "$ARCHIVE_DIR" -A "$BACKUP_DIR")