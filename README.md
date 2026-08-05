# encoder_params.sh

Batch video encoder for Plex media libraries. Processes single files, directories, or globs with stream-aware copy/transcode decisions: copying streams that are already in the target format and only re-encoding what needs to change. Mirrors input directory structure in output, with optional post-encode archiving to a NAS and source file backup.

---

## Requirements

- **bash** 4.0+
- **ffmpeg** and **ffprobe**
- **python3**

---

## Quick Start

```bash
# Encode everything in a directory, recurse subdirectories, skip existing output
./scripts/encoder_params.sh -r -s -o "/home/patrick/Videos/#encoding" "/home/patrick/Videos/#pre-encode"

# Full pipeline: encode, archive output, backup source files
./scripts/encoder_params.sh -r -s \
  -o "/home/patrick/Videos/#encoding" \
  -M "/home/patrick/Videos/#post-encode" \
  -A "/home/patrick/Videos/#backup" \
  "/home/patrick/Videos/#pre-encode"

# Dry run: print all decisions without encoding
./scripts/encoder_params.sh -r -s -n -o "/home/patrick/Videos/#encoding" "/home/patrick/Videos/#pre-encode"
```

---

## Options

| Flag | Argument | Default | Description |
|------|----------|---------|-------------|
| `-o` | `DIR` | `./encoded` | Output directory |
| `-c` | `INT` | `18` | CRF quality, 0–51. Lower = better quality, larger file |
| `-p` | `PRESET` | `slow` | x264 encode preset: `ultrafast` `superfast` `veryfast` `faster` `fast` `medium` `slow` `slower` `veryslow` |
| `-b` | `BITRATE` | `192k` | Audio fallback bitrate when re-encoding to AAC |
| `-H` | `HEIGHT` | `1080` | Maximum output height in pixels. Sources taller than this are scaled down |
| `-f` | `FORMAT` | `mkv` | Output container: `mkv` or `mp4` |
| `-l` | `LANGS` | `eng` | Comma-separated subtitle languages to keep (ISO 639-2). Also determines which sidecar `.srt` languages are looked for (see [Sidecar subtitles](#sidecar-subtitles)) |
| `-a` | `CODECS` | `aac,ac3,eac3,dts,truehd,flac,opus` | Audio codecs to copy without re-encoding |
| `-e` | `EXTS` | see below | Comma-separated input file extensions to scan |
| `-L` | `DIR` | `OUTPUT_DIR/Logs` | Log file directory |
| `-M` | `PATH` | n/a | Archive output files here after encode (cross-device safe: cp + verify + rm) |
| `-A` | `PATH` | n/a | Move source input files here after encode (same-device mv) |
| `-d` | `BYTES` | `10737418240` | Minimum free disk space before aborting (default 10 GB) |
| `-P` | `SIZE` | `10M` | ffmpeg `-analyzeduration` and `-probesize` value |
| `-r` | n/a | off | Recurse into subdirectories, mirroring folder structure in output |
| `-F` | n/a | off | Flat output: do not mirror directory structure. File and glob inputs are always flat regardless of this flag; `-F` only changes behavior for directory inputs run with `-r`. |
| `-n` | n/a | off | Dry run: print all decisions, do not encode |
| `-s` | n/a | off | Skip files whose output already exists (default: overwrite) |
| `-h` | n/a | n/a | Show help |

### Default input extensions

`mp4 mkv avi mov ts m4v wmv flv webm vob ogv 3gp mpg mpeg divx`

Override with `-e mkv,mp4` to restrict to specific formats.

---

## Encoding Decisions

### Video

The script probes each file before encoding and makes a copy or encode decision per stream.

| Condition | Action |
|-----------|--------|
| Source is h264 and height ≤ `MAX_HEIGHT` | Copy: no re-encode |
| Source is any other codec | Re-encode to x264 |
| Source height > `MAX_HEIGHT` | Re-encode and scale down to `MAX_HEIGHT` |

x264 encode parameters: CRF `-c`, preset `-p`, `yuv420p`, High profile, Level 4.1.

If the source is HEVC, the script prints a warning to stderr before encoding starts (see [hevc sources](#hevc-sources) below).

### Audio

| Condition | Action |
|-----------|--------|
| Source codec is in the copy list (`-a`) | Copy: no re-encode |
| Source codec is not in the copy list | Re-encode to AAC at `-b` bitrate |

All audio streams are included. Stream order is preserved. Non-contiguous source stream indices are handled correctly.

### Subtitles

Only streams matching the target language list (`-l`) are included. The following are excluded regardless of language:

- Signs & Songs tracks (detected by track title containing `sign` or `song`)
- Duplicate standard tracks of the same language beyond the first
- Bitmap subtitle formats (PGS, VobSub, DVB) when the output container is MP4

Subtitle codec selection is container-aware:

| Container | Text formats | `mov_text` sources | Bitmap formats |
|-----------|-------------|---------------------|----------------|
| MKV | `copy` | converted to `srt` | `copy` |
| MP4 | `mov_text` | `mov_text` | dropped |

`mov_text` is an MP4/MOV-only binary subtitle codec; Matroska has no muxer support for it at all, so a source `.mp4` with `mov_text` subtitles being remuxed to `.mkv` cannot use a plain stream copy for that track. The script detects this case and transcodes to `srt` (plain text, natively supported by Matroska) instead. All other text formats (SRT, ASS, SSA) and bitmap formats already valid in MKV are copied unchanged.

### Sidecar subtitles

For each target language in `-l`, the script also looks for Plex-convention external `.srt` files sitting next to the input, using an exact filename match (no globbing):

| Sidecar filename | Track type |
|-------------------|------------|
| `Movie.<lang>.srt` | Standard |
| `Movie.<lang>.cc.srt` or `Movie.<lang>.sdh.srt` | CC (if both exist, `.cc.` is preferred and `.sdh.` is ignored) |
| `Movie.<lang>.forced.srt` | Forced |

`<lang>` is the 2-letter Plex/ISO 639-1 code (`en`, `fr`, `de`, ...), mapped internally to the 3-letter code used everywhere else in the script.

**Sidecar wins.** If a sidecar file exists for a language, any embedded subtitle track in that same language is dropped entirely: the sidecar replaces it rather than sitting alongside it. A file with an embedded English track plus `Movie.en.srt` ends up with one English subtitle track in the output, sourced from the sidecar.

Sidecar `.srt` files are muxed in through the same container-aware codec logic as embedded tracks (`copy` for MKV, `mov_text` for MP4) and use the same naming rules below, so a sidecar-sourced track is indistinguishable from an embedded one once encoded.

---

## Track Naming

All output tracks are titled with plain-English display names. Source metadata is stripped and replaced with clean values.

### Video
`{Codec} {Height}p`, e.g. `H.264 1080p`. Always reflects the output codec and output height, not the source.

### Audio
`{Codec} {Language} {Layout}`

Examples:
- `AAC English Stereo`
- `DTS English 5.1`
- `TrueHD English 7.1`
- `Opus French Stereo`
- `AAC English 6ch`: fallback when channel layout is not a named format

When a track is re-encoded to AAC, the codec portion of the title is updated to `AAC` while the language and layout are preserved.

Untagged tracks (`und`) default to `English`.

### Subtitles
`{Language}`, with a suffix for special track types:

- `English`: standard track
- `English CC`: hearing impaired / SDH / CC
- `English Forced`: forced track

CC tracks are identified by the `hearing_impaired` ffmpeg disposition flag or by source track titles containing: `sdh`, `cc`, `hi`, `hearing impaired`, `closed caption`, `closed captions`. The `hearing_impaired` disposition flag is set on CC tracks in the output. This naming is independent of the underlying subtitle codec, so a `mov_text` track converted to `srt` for MKV output keeps the same title it would have gotten as a straight copy. Sidecar `.srt` files are titled the same way based on their filename suffix (`.cc.`/`.sdh.` → CC, `.forced.` → Forced, otherwise standard).

---

## Directory Structure

Input directory structure is mirrored in the output by default when using `-r`. Given:

```
Pending/
  Movies/
    Name, The/(YYYY) Name, The/Name, The.mkv
  Series/
    Name (YYYY)/Season 01/S01E01.mkv
```

Output mirrors to:

```
Complete/
  Movies/
    Name, The/(YYYY) Name, The/Name, The.mkv
  Series/
    Name (YYYY)/Season 01/S01E01.mkv
```

Use `-F` to disable mirroring for directory inputs run with `-r` (see `-F` in [Options](#options) above).

---

## Post-Encode Pipeline

Two independent post-encode actions run after each successful encode. Either or both may be specified. A failure in either does not retroactively fail the encode.

### `-M PATH`: Archive output to NAS

Copies the completed output file to `PATH`, mirroring the same relative directory structure. Uses `cp` + size verification + `rm` to safely handle cross-device destinations (SMB mounts, NFS, etc.).

- If `cp` fails, the operation is aborted and logged as a warning
- If the destination size does not match the source after copy, the destination is removed and the failure is logged
- If `stat` fails on either side, the operation aborts without removing anything
- Empty directories left behind in the output directory are cleaned up after the move

### `-A PATH`: Backup source input

Moves the original source file to `PATH` after a successful encode, mirroring the relative path from the collection root. Uses `mv` (same-device operation).

- Empty directories left behind in the source directory are cleaned up after the move
- Any sidecar `.srt` file that was muxed into the output moves to `PATH` alongside the source video, mirrored the same way, so a video and its sidecar subtitles stay together in the backup tree instead of leaving orphaned `.srt` files behind in the input directory

Archive and backup act on two different files by design: archive copies the encoded *output* (always carrying the `-f` container extension), backup moves the original *source* input (whatever extension it arrived with). Seeing different extensions in the log for the same title is expected, not an error.

### Example pipeline

```
Pending/Movies/Name/(YYYY) Name/Name.mkv
  ├─ encode → Complete/Movies/Name/(YYYY) Name/Name.mkv
  │              └─ cp + verify + rm → /mnt/plexmedia/#archive/Movies/Name/(YYYY) Name/Name.mkv
  └─ mv → "#backup (From Pending)"/Movies/Name/(YYYY) Name/Name.mkv
```

---

## Logging

Each batch run produces a single log file.

On a clean run (no failures), the log is moved to `LOG_DIR` (`OUTPUT_DIR/Logs` by default) and named `Log_YYYY-MM-DD_HHMM.txt`.

If any file fails, the log remains in `OUTPUT_DIR` as `Log_InProgress.txt` for immediate visibility alongside the incomplete output.

Dry runs always leave the log in `OUTPUT_DIR` as `Log_InProgress.txt`: nothing was encoded, so no run is finalized.

If a leftover `Log_InProgress.txt` from a previous failed or interrupted run is found at startup, it is preserved (not overwritten) as `LOG_DIR/Log_FAILED_<timestamp>.txt` before the new run's log is created.

### Log entries

Each processed file produces entries of the form:

```
[2026-06-27 09:34:10] PROCESSING: Movie.mkv
[2026-06-27 09:34:14] COMPLETED: Movie.mkv [H.264] | 0m 4s | src: 4115MB → out: 2936MB (-28%)
```

Additional entries on failure or warning:

```
[2026-06-27 09:34:14] FAILED: /path/to/input (exit 1) | 0m 0s
[2026-06-27 09:34:14] FFMPEG WARNING: Movie.mkv | Could not find codec parameters for stream (Subtitle: hdmv_pgs_subtitle): unspecified size
[2026-06-27 09:34:14] SIZE WARNING: Movie.mkv | output 2936MB exceeds source 2900MB (+1%)
[2026-06-27 09:34:14] SKIPPED: Movie.mkv
[2026-06-27 09:34:14] ARCHIVED: Movie.mkv
[2026-06-27 09:34:14] BACKED UP: Movie.mkv
```

`PROCESSING`, `COMPLETED`, `FFMPEG WARNING`, `SIZE WARNING`, `SKIPPED`, `ARCHIVED`, and `BACKED UP` log the file's basename only. `FAILED` is the exception: it logs the full input path exactly as passed on the command line, since a failure is when the full original location matters most. `ARCHIVED` and `BACKED UP` do not record a destination path; they confirm only that the step completed for that file. `FAILED` entries carry a reason tag: `FAILED (probe): ...`, `FAILED (empty output): ...`, `FAILED (no video stream): ...`, or plain `FAILED: ... (exit N)` for an ffmpeg failure.

### Batch summary

The end-of-run summary reports four categories:

```
 Batch complete
  OK:        21
  Skipped:   2
  Previewed: 0
  Failed:    1
```

- **OK**: encoded successfully
- **Skipped**: output already existed and `-s` was set
- **Previewed**: dry run (`-n`); nothing was written, re-run without `-n` to encode
- **Failed**: ffmpeg error, probe error, or empty output

`Previewed` is only printed when a dry run was performed, so a normal batch summary omits it. Dry-run previews and existing-output skips are counted separately: a dry run of files that don't exist yet always reports under `Previewed`, never `Skipped`.

### ffmpeg warnings

ffmpeg's stderr output is captured per file and scanned for known warning patterns. Any matches are written to the batch log. Patterns monitored:

- `Could not find codec parameters`: stream dropped or undetected (common with PGS subtitles)
- `Invalid data found`
- `Error while decoding`
- `Error while opening`
- `non-existing PPS`
- `missing reference picture`
- `concealing errors`
- `corrupt decoded frame`
- `Application provided invalid`

A fatal ffmpeg error that doesn't match one of these patterns is still printed to the terminal in real time, but is not written to the persistent log; only the exit code is recorded (e.g. `FAILED: ... (exit 218)`). If a batch fails with no matching warning text in the log, rerun the affected file with `-n` to get the exact constructed `ffmpeg` command, then run that command manually in the terminal to see the uncaptured error.

---

## Atomic Output

Output is written to a hidden `.tmp` file (`.Name.tmp.mkv`) and renamed to the final path only on success. This means:

- A killed or failed encode never leaves a file that looks complete
- Rerunning with `-s` will not skip a file that failed mid-encode
- On SIGINT or SIGTERM, the partial `.tmp` file is removed automatically

---

## Interruption and Recovery

On `Ctrl+C` or SIGTERM:

1. The running ffmpeg process is killed
2. The partial `.tmp` output file is removed
3. A partial summary is written to the log
4. The log is retained in `OUTPUT_DIR` as `Log_InProgress.txt`

To resume a batch, rerun with `-s` to skip files that completed successfully.

---

## Disk Space

Before each file encode, the script checks that at least `-d` bytes (default 10 GB) are free in the output directory filesystem. If the check fails, the batch is aborted immediately with a summary written to the log.

---

## Notes

### CRF and preset guidance

| Use case | Suggested settings |
|----------|--------------------|
| Archival quality | `-c 16 -p slow` |
| Default (Plex) | `-c 18 -p slow` |
| Faster encoding, minimal quality loss | `-c 18 -p medium` |
| Quick encode / preview | `-c 22 -p fast` |

Use these as pairs, not as independently mixable rows. `-c 22 -p slow` combines the lowest-quality CRF band with the most expensive preset band: it gets neither the speed of the "quick" row nor the size gains of the lower-CRF rows. CRF 22 is already too coarse to beat most modern source encodes, so the added preset time frequently produces output equal to or larger than the source.

### hevc sources

hevc (H.265) is more efficient than h264, so transcoding hevc → x264 always produces a larger file and takes longer. Before encoding hevc sources, verify whether your Plex client can direct-play hevc: modern clients (Apple TV 4K, Roku Ultra, NVIDIA Shield) can, which makes transcoding unnecessary.

### MP4 compatibility

When using `-f mp4`:

- PGS, VobSub, and DVB bitmap subtitle formats are dropped (incompatible with MP4)
- Text subtitle formats (SRT, ASS, SSA) are re-muxed as `mov_text`
- `-movflags +faststart` is applied for streaming compatibility

### MKV compatibility

When using `-f mkv` (default):

- `mov_text` subtitle sources (common in MP4-sourced rips) are transcoded to `srt`: Matroska cannot mux `mov_text` at all, and a plain stream copy of it fails the encode outright (see [Design Notes](#mov_text-copied-into-mkv-fails-the-mux) below)
- All other text formats (SRT, ASS, SSA) and bitmap formats (PGS, VobSub, DVB) are copied unchanged: MKV supports all of these natively

---

## Design Notes

Non-obvious decisions made during development, preserved to prevent accidental regression.

### `mov_text` copied into MKV fails the mux

Subtitle codec selection originally used a flat `copy` for any text format when the output container was MKV. This works for SRT/ASS/SSA sources, but `mov_text` (the subtitle codec MP4/MOV containers use) has no Matroska muxer support whatsoever. Copying it into an `.mkv` fails at header-write time with `Subtitle codec 94213 is not supported` / `Could not write header (incorrect codec parameters ?): Function not implemented`, which aborts the entire file with a bare ffmpeg exit code and no further detail in the log (the error text doesn't match any pattern in `log_ffmpeg_warnings`). `subtitle_output_codec()` now special-cases `mov_text` for MKV output and transcodes it to `srt` instead of copying.

### `-stats` removed from ffmpeg

ffmpeg's `-stats` flag writes live progress to stderr. When stderr was redirected to a capture file for warning logging, `-stats` caused ffmpeg to stall: the OS pipe buffer filled as the capture file was never read during encoding. Replaced with a bash spinner (elapsed time) that polls ffmpeg's process ID every second. `-nostats` suppresses ffmpeg's own progress output entirely.

### `&& _RC=0 || _RC=$?` in the main loop

Under `set -e`, a function returning non-zero on a bare line aborts the script before `$?` can be read. The `&&`/`||` chain makes the compound expression always exit 0 from `set -e`'s perspective while still capturing the real return code. A semicolon (`process_file ...; _RC=$?`) does not suppress `set -e` and was tried and reverted.

### `${ARRAY[@]+"${ARRAY[@]}"}` for empty arrays

Under `set -u`, expanding an empty array with `"${ARRAY[@]}"` throws `unbound variable` in bash < 4.4. The `+` form expands to nothing when the array is empty and expands normally otherwise. Used for `CONTAINER_FLAGS`, `DEPTH_FLAG`, `AUDIO_LINES`, and `SUB_LINES`.

### ffmpeg stderr capture: direct redirect, not `tee`

The original implementation used `2> >(tee "$STDERR_CAPTURE" >&2)` to show live output and capture simultaneously. This creates a race: the `tee` subprocess may not have flushed the capture file by the time `log_ffmpeg_warnings` reads it, causing warnings to be silently missed. The capture now uses a direct `2> "$STDERR_CAPTURE"` redirect with `cat` to the terminal after ffmpeg exits.

### `sort -u` deduplication in `log_ffmpeg_warnings`

The original loop ran one `grep` per pattern, meaning a warning line matching two patterns was logged twice. Replaced with a single `grep -iE` pass across all patterns piped through `sort -u`. PGS per-stream warnings are additionally collapsed by `sed` before deduplication so three PGS subtitle streams produce one log entry, not three.

### Video track title set at encode time, not probe time

The probe previously computed `video_title` (e.g. `H.265 1040p`) from the source codec and passed it through to the output track metadata. A hevc source re-encoded to x264 would be titled `H.265 1040p` in the output, which is incorrect. Title is now derived inside `build_video_args` after the copy/encode decision: copy path uses the source codec, encode path always writes `H.264 Np`.

### Audio re-encode title uses `${AUDIO_TITLE#* }` not `${AUDIO_TITLE##* }`

`AUDIO_TITLE` is of the form `Codec Language Layout` (e.g. `DTS English 5.1`). When re-encoding to AAC, only the codec word should be replaced. `##*` strips everything up to the last space, keeping only `5.1`. `#*` strips only the first word, keeping `English 5.1`, which is correct.

### `stat` failure in `archive_output` does not delete the destination

If `stat` fails on either the source or destination after a copy (e.g. a transient NAS hiccup), the size comparison would produce a false mismatch and the archived copy would be deleted despite being potentially valid. Explicit `stat` failure checks abort the verification step and leave the destination in place.

### Log finalizes only on zero failures; skips are not failures

A batch that processes 100 files and intentionally skips 50 existing ones (via `-s`) is a clean run. The log moves to `Logs/` only when `ENCODE_FAIL -eq 0`. Skips do not retain the log in `OUTPUT_DIR`. Dry runs always retain the log since nothing was actually encoded.

### Source codec logged alongside COMPLETED entries

`COMPLETED` log lines include the source video codec label (e.g. `[H.265]`), populated from the same probe result already used in `build_video_args`. Size deltas on HEVC sources are otherwise unreadable without cross-referencing PROCESSING lines against the source files by hand.

### Size-diff sign computed by comparison, not by truncated percentage

The percentage in `SIZE WARNING` / `COMPLETED` lines is derived from `(( OUT_BYTES > SRC_BYTES ))` / `(( OUT_BYTES < SRC_BYTES ))` directly, not from the sign of a truncated integer division. Bash integer division truncates toward zero, so a file that shrank by a fraction of a percent previously computed `PCT=0` and printed as `+0%`, indistinguishable from genuine growth.

### Leftover `Log_InProgress.txt` is preserved, not overwritten

A failed or interrupted batch intentionally leaves `Log_InProgress.txt` in `OUTPUT_DIR` rather than moving it to `Logs/`, so the failure is visible without digging through a `Logs/` directory. But the next run's setup previously just warned and then truncated that same file, permanently discarding the prior failure's log before anyone could read it. Startup now moves any leftover `Log_InProgress.txt` into `Logs/Log_FAILED_<timestamp>.txt` first, so a failed run's log always survives the next invocation.

### Dry run and skip-existing use separate return codes

`process_file()` originally returned `2` for both a dry-run preview and a real `-s` skip (output already exists), so both were tallied under `Skipped` in the batch summary. A dry run of files that hadn't been encoded yet then looked identical in the summary to a run where every output already existed, misleading when skimming just the final counts. Dry run now returns `3` and is tallied separately as `Previewed`.

### Sidecar subtitle language matching is exact, not globbed

Sidecar discovery checks for literal filenames (`Movie.en.srt`, `Movie.en.cc.srt`, etc.) rather than globbing `*.srt` in the input directory. Season-pack naming makes prefix collisions a real risk: a loose match could pick up `Show - S01E10.en.srt` while processing `Show - S01E1.mp4`. Exact string comparison against the computed basename avoids this entirely.

### Sidecar wins over embedded, per language, unconditionally

A source file can have both an embedded subtitle track and a sidecar `.srt` in the same language. Rather than keeping both (which would trip the existing "duplicate standard track" dedup logic and produce an untitled second track) or preferring the embedded track, the embedded track for that language is dropped outright whenever a sidecar exists. Sidecars are usually hand-fetched or corrected, so this is the least-surprising default, and it keeps the "duplicate track" dedup logic focused solely on genuine embedded-vs-embedded duplicates.

### Embedded and sidecar subtitles share one output index counter

`build_subtitle_args` (embedded) and `build_external_subtitle_args` (sidecar) both take the same index variable by reference and increment it in place, rather than each starting from 0. This is what makes a sidecar-sourced track genuinely indistinguishable from an embedded one in the output (same numbering scheme, same title format, same disposition handling) rather than being a visibly separate, bolted-on set of trailing tracks.

### Sidecar record field order: path must be last

Internally, each discovered sidecar is passed around as a single space-delimited string (`LANG TYPE INPUT_IDX PATH`) and split back apart with `read`. `read` assigns extra tokens to its *last* named variable, which is the only safe way to reconstruct a field that might itself contain spaces: directory names like `(2022) Movie Title` are common in this collection layout. This record originally put the path before the trailing input index (`LANG TYPE PATH IDX`); a space in the path caused `read` to truncate `SIDECAR_PATH` at the first space and shove the remainder of the path plus the real index into `SIDECAR_INPUT_IDX`, producing a garbage `-map` value (`Movie/Movie.en.srt 1:0`) that ffmpeg rejected outright. The fix follows the same convention already used by the embedded `SUB`/`AUDIO` probe records elsewhere in the script: variable-width, free-text fields always go last.