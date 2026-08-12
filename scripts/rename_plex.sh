#!/usr/bin/env bash
# rename_plex_media.sh: Rename movie video/subtitle files into Plex naming
#                        convention, with subtitle language tags normalized
#                        to the 2-letter codes encoder_params.sh's sidecar
#                        matching (discover_sidecar_subs) requires.
#
# Usage:  ./rename_plex_media.sh [OPTIONS] <target_dir>
#
# Options:
#   -n              Dry run: print decisions, do not rename (default: off)
#   -f              Force: overwrite destination if a rename target already
#                   exists (default: off — collisions are skipped and logged)
#   -L DIR          Log directory (default: TARGET_DIR/Logs)
#   -h              Show this help
#
# Notes:
#   • Requires bash 4.0+
#   • Only one run may target a given <target_dir> at a time; a second run
#     against the same directory exits immediately instead of racing on
#     shared rename targets (same lock convention as encoder_params.sh)
#   • Only files matching "Name (YYYY)..." are touched; anything else is left
#     alone and counted as "No match"
#   • Subtitle language tags are normalized against lang_table.sh (shared
#     with encoder_params.sh's -l flag and sidecar lookup, same directory)
#     — e.g. .eng.srt and .fre.srt become .en.srt and .fr.srt
#   • Requires lang_table.sh and lang_table.tsv alongside this script
#   • Subtitle modifiers are only ever written as cc, sdh, or forced — the
#     exact three literal forms encoder_params.sh's discover_sidecar_subs()
#     matches. Anything else (unrecognized language, unrecognized modifier)
#     is skipped rather than guessed, since a wrong guess here means the
#     encoder silently drops that subtitle later with no error of its own.

set -euo pipefail

# ── Bash version guard ────────────────────────────────────────────────────────
if (( BASH_VERSINFO[0] < 4 )); then
    echo "ERROR: bash 4.0+ required (current: $BASH_VERSION)" >&2
    exit 1
fi

# ── Defaults ──────────────────────────────────────────────────────────────────
DRY_RUN=0
FORCE=0
LOG_DIR=""

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,2\}//'
    exit 0
}

# ── Arg parsing ───────────────────────────────────────────────────────────────
while getopts ":L:nfh" opt; do
    case $opt in
        L) LOG_DIR="$OPTARG" ;;
        n) DRY_RUN=1 ;;
        f) FORCE=1 ;;
        h) usage ;;
        :) echo "ERROR: Option -$OPTARG requires an argument." >&2; exit 1 ;;
        \?) echo "ERROR: Unknown option: -$OPTARG" >&2; exit 1 ;;
    esac
done
shift $(( OPTIND - 1 ))

[[ $# -eq 1 ]] || {
    echo "Usage: $0 [OPTIONS] <target_dir>" >&2
    echo "  Run $0 -h for full help." >&2
    exit 1
}
TARGET_DIR="${1%/}"

if [[ ! -d "$TARGET_DIR" ]]; then
    echo "ERROR: Target directory '$TARGET_DIR' does not exist." >&2
    exit 1
fi

# ── Dependency check ──────────────────────────────────────────────────────────
require() { command -v "$1" &>/dev/null || { echo "ERROR: '$1' not found on PATH" >&2; exit 1; }; }
require find
require flock

# ── Concurrency lock ──────────────────────────────────────────────────────────
# Only one run may target a given TARGET_DIR at a time: two runs sharing it
# could both compute the same rename target for the same file and race on
# the same mv. Exclusive, non-blocking; released automatically on exit (fd 9
# closes). Same lock filename convention as encoder_params.sh's OUTPUT_DIR
# lock, so a rename and an encode pointed at the same directory (e.g. a
# rename run against already-encoded output) block each other too, not just
# same-script collisions.
LOCK_FILE="$TARGET_DIR/.media.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
    echo "ERROR: another run is already active against $TARGET_DIR (lock: $LOCK_FILE)" >&2
    exit 1
fi

# ── Extensions ────────────────────────────────────────────────────────────────
VIDEO_EXTS="mkv|mp4|avi|mov|m4v"
SUB_EXTS="srt|vtt|ass|idx|sub"
ALL_EXTS="${VIDEO_EXTS}|${SUB_EXTS}"

# ── Language alias table ──────────────────────────────────────────────────────
# LANG_ALIASES comes from the shared lang_table.sh / lang_table.tsv (same
# directory) — the same source encoder_params.sh's sidecar matching and its
# Python probe step both read.
source "$(dirname "${BASH_SOURCE[0]}")/lang_table.sh"

normalize_lang() {
    local raw="${1,,}"
    echo "${LANG_ALIASES[$raw]:-}"
}

# Only cc, sdh, and forced are meaningful to encoder_params.sh's sidecar
# lookup. Anything else comes back empty and the caller treats it as unknown
# rather than writing a modifier the encoder will never match.
normalize_modifier() {
    local raw="${1,,}"
    case "$raw" in
        cc|sdh|forced) echo "$raw" ;;
        *) echo "" ;;
    esac
}

# ── Counters ──────────────────────────────────────────────────────────────────
RENAMED=0
PREVIEWED=0
SKIPPED=0
NO_MATCH=0
FAILED=0

# ── Log setup ─────────────────────────────────────────────────────────────────
[[ -z "$LOG_DIR" ]] && LOG_DIR="$TARGET_DIR/Logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/Rename_$(date '+%Y-%m-%d_%H%M').txt"
# Unlike encoder_params.sh's Log_InProgress.txt → finalize-on-success dance,
# this writes directly to its final path: a rename pass is seconds long and
# fully idempotent (already-correct names are simply left alone on a re-run),
# so there's no meaningful "interrupted mid-batch" state worth preserving
# separately.
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

echo "Starting Plex library scan (Videos & Subtitles)..."
(( DRY_RUN )) && echo "=== RUNNING IN DRY-RUN MODE (No changes will be made) ==="
echo "----------------------------------------------------------------"
log "Rename pass started: $TARGET_DIR"

# ── Main loop ─────────────────────────────────────────────────────────────────
# Null-delimited find + process substitution (not a pipe) so counters set
# inside the loop are visible after it ends — a `find ... | while read` loop
# runs the loop body in a subshell and silently discards them.
while IFS= read -r -d '' FILE_PATH; do

    FILE_NAME="$(basename "$FILE_PATH")"
    FILE_DIR="$(dirname "$FILE_PATH")"
    FILE_EXT="${FILE_NAME##*.}"
    FILE_EXT_LOWER="${FILE_EXT,,}"

    IS_SUBTITLE=0
    [[ "$FILE_EXT_LOWER" =~ ^(${SUB_EXTS})$ ]] && IS_SUBTITLE=1

    # 1. PARSE: Movie Name, Year, and everything after the year's ")".
    #    The leading (.*) is intentionally greedy so that a title containing
    #    its own parenthetical (e.g. "Movie (Director's Cut) (2020)") still
    #    anchors on the rightmost "(YYYY)" rather than the first parenthesis.
    if [[ "$FILE_NAME" =~ ^(.*)\(([0-9]{4})\)(.*)$ ]]; then
        MOVIE_NAME="${BASH_REMATCH[1]}"
        YEAR="${BASH_REMATCH[2]}"
        TRAILING_STUFF="${BASH_REMATCH[3]}"
    else
        echo "NO MATCH (no valid Year structure found): $FILE_NAME"
        log "NO MATCH: $FILE_NAME"
        NO_MATCH=$(( NO_MATCH + 1 ))
        continue
    fi

    MOVIE_NAME="$(echo "$MOVIE_NAME" | sed -e 's/[[:space:]]*-[[:space:]]*$//' -e 's/[[:space:]]*$//')"

    # 2. EDITION + SUBTITLE METADATA
    EDITION=""
    if [[ "$TRAILING_STUFF" =~ \{edition-([^}]+)\} ]]; then
        EDITION="${BASH_REMATCH[1]}"
    fi

    SUB_LANG_TAG=""
    UNRECOGNIZED_SUB_TAG=0
    if (( IS_SUBTITLE )); then
        CLEAN_TRAILING="$(echo "$TRAILING_STUFF" | sed 's/{edition-[^}]*}//g')"

        # Matches ".<lang>.srt" or ".<lang>.<modifier>.srt" — lang is
        # captured separately from an optional modifier so each can be
        # normalized independently instead of carried through verbatim.
        if [[ "$CLEAN_TRAILING" =~ ^\.([A-Za-z]{2,3})(\.([A-Za-z]+))?\.[A-Za-z0-9]+$ ]]; then
            RAW_LANG="${BASH_REMATCH[1]}"
            RAW_MOD="${BASH_REMATCH[3]}"

            NORM_LANG="$(normalize_lang "$RAW_LANG")"
            if [[ -z "$NORM_LANG" ]]; then
                echo "SKIPPING (unrecognized subtitle language '$RAW_LANG'): $FILE_NAME"
                log "SKIPPED (unrecognized language '$RAW_LANG'): $FILE_NAME"
                SKIPPED=$(( SKIPPED + 1 ))
                continue
            fi

            NORM_MOD=""
            if [[ -n "$RAW_MOD" ]]; then
                NORM_MOD="$(normalize_modifier "$RAW_MOD")"
                if [[ -z "$NORM_MOD" ]]; then
                    echo "SKIPPING (unrecognized subtitle modifier '$RAW_MOD'): $FILE_NAME"
                    log "SKIPPED (unrecognized modifier '$RAW_MOD'): $FILE_NAME"
                    SKIPPED=$(( SKIPPED + 1 ))
                    continue
                fi
            fi

            SUB_LANG_TAG=".${NORM_LANG}"
            [[ -n "$NORM_MOD" ]] && SUB_LANG_TAG="${SUB_LANG_TAG}.${NORM_MOD}"
        else
            # No language tag at all (e.g. plain "Movie (2020).srt") is left
            # untagged, same as the original behavior — Plex convention only
            # requires a language suffix when disambiguating multiple tracks.
            :
        fi
    fi

    # 3. REBUILD
    if [[ -n "$EDITION" ]]; then
        CLEAN_PLEX_NAME="$MOVIE_NAME ($YEAR) {edition-$EDITION}"
    else
        CLEAN_PLEX_NAME="$MOVIE_NAME ($YEAR)"
    fi

    NEW_FILE_NAME="${CLEAN_PLEX_NAME}${SUB_LANG_TAG}.${FILE_EXT_LOWER}"
    NEW_FILE_PATH="${FILE_DIR}/${NEW_FILE_NAME}"

    [[ "$FILE_NAME" == "$NEW_FILE_NAME" ]] && continue

    # 4. COLLISION CHECK
    if [[ -e "$NEW_FILE_PATH" ]] && (( ! FORCE )); then
        echo "SKIPPING (rename target already exists, use -f to overwrite): $NEW_FILE_NAME"
        log "SKIPPED (collision): $FILE_NAME -> $NEW_FILE_NAME"
        SKIPPED=$(( SKIPPED + 1 ))
        continue
    fi

    TYPE_LABEL="Video"
    (( IS_SUBTITLE )) && TYPE_LABEL="Subtitle"
    echo "MATCH FOUND (${TYPE_LABEL}):"
    echo "  Current path:  $FILE_PATH"
    echo "  Cached Data:   Name: '$MOVIE_NAME' | Year: '$YEAR' | Edition: '$EDITION' | Lang: '$SUB_LANG_TAG'"
    echo "  New Filename:  $NEW_FILE_NAME"

    # 5. EXECUTE
    if (( DRY_RUN )); then
        echo "  [DRY RUN] Would rename to: $NEW_FILE_PATH"
        log "PREVIEWED: $FILE_NAME -> $NEW_FILE_NAME"
        PREVIEWED=$(( PREVIEWED + 1 ))
    else
        if mv -- "$FILE_PATH" "$NEW_FILE_PATH"; then
            echo "  [SUCCESS] Renamed."
            log "RENAMED: $FILE_NAME -> $NEW_FILE_NAME"
            RENAMED=$(( RENAMED + 1 ))
        else
            echo "  [FAILED] mv error" >&2
            log "FAILED (mv): $FILE_NAME -> $NEW_FILE_NAME"
            FAILED=$(( FAILED + 1 ))
        fi
    fi
    echo "----------------------------------------------------------------"

done < <(find "$TARGET_DIR" -type f -regextype posix-extended -iregex ".*\.(${ALL_EXTS})$" -print0 | sort -z)

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "------------------------------------------"
echo " Batch complete"
echo "  Renamed:    $RENAMED"
(( DRY_RUN )) && echo "  Previewed:  $PREVIEWED  (dry run: nothing written; re-run without -n to rename)"
echo "  Skipped:    $SKIPPED  (collisions or unrecognized language/modifier — review manually)"
echo "  No match:   $NO_MATCH  (no \"Name (YYYY)\" pattern found; left untouched)"
echo "  Failed:     $FAILED"
echo "------------------------------------------"
log "Batch complete: Renamed=$RENAMED Previewed=$PREVIEWED Skipped=$SKIPPED NoMatch=$NO_MATCH Failed=$FAILED"
echo "Log saved to: $LOG_FILE"

[[ $FAILED -eq 0 ]] || exit 1