# video-encoder

Batch video encoding and Plex media renaming for a personal media library, with a shared configuration layer, a concurrency lock, and a single source of truth for subtitle language codes.

```
video-encoder/
├── .git/
├── README.md                  ← this file
└── scripts/
    ├── config.sh               Shared paths, flags, and the concurrency lock
    ├── encoder_dry.sh           Preview an encode batch (writes nothing)
    ├── encoder.sh                Run an encode batch for real
    ├── encoder_params.sh       Core batch encoder (called by the two above; can also be run standalone)
    ├── rename_dry.sh            Preview a rename batch (writes nothing)
    ├── rename.sh                  Run a rename batch for real
    ├── rename_plex.sh          Plex-convention renamer for movies + subtitles (called by the two above; can also be run standalone)
    ├── lang_table.sh           Shared language-code loader (bash side)
    └── lang_table.tsv          Canonical language data (single source of truth)
```

---

## Workflow

### 1. Encode a batch

```bash
cd scripts
./encoder_dry.sh    # preview — review the plan, nothing is written
./encoder.sh         # run it for real
```

Both wrappers source `config.sh` for paths/flags and call the real work out to `encoder_params.sh`. Never run `encoder_dry.sh` and `encoder.sh` at the same time against the same output directory — see [Concurrency lock](#concurrency-lock).

To change quality, paths, or run against a different tree without editing any file:

```bash
CRF=18 PRESET=slow ./encoder.sh
VIDEOS_BASE=/mnt/scratch/Videos ./encoder_dry.sh
```

### 2. Rename a library into Plex convention

```bash
cd scripts
./rename_dry.sh    # preview — review the plan, nothing is written
./rename.sh          # run it for real
```

Both wrappers source `config.sh` and target `$INPUT_DIR` — the same directory `encoder_dry.sh`/`encoder.sh` read from — so a rename pass and an encode pass by default operate on the same tree without any path juggling. To rename a directory other than `$INPUT_DIR` (e.g. after archiving), call `rename_plex.sh` directly with an explicit target instead of going through the wrappers.

### 3. Rename, then encode

```bash
./rename_dry.sh && ./rename.sh
./encoder_dry.sh && ./encoder.sh
```

Run rename to completion before encoding: filenames must already be correct by the time the encoder builds sidecar-subtitle paths from them.

---

## `config.sh`

Defines, from a single `VIDEOS_BASE` (default `$HOME/Videos`):

| Variable | Default | Passed to `encoder_params.sh` as |
|---|---|---|
| `INPUT_DIR` | `$VIDEOS_BASE/input` | positional arg |
| `OUTPUT_DIR` | `$VIDEOS_BASE/output` | `-o` |
| `ARCHIVE_DIR` | `$VIDEOS_BASE/encoded` | `-M` |
| `BACKUP_DIR` | `$VIDEOS_BASE/backup` | `-A` |
| `CRF` | `22` | `-c` |
| `PRESET` | `fast` | `-p` |

No paths or usernames are hardcoded — everything derives from `$HOME` unless overridden.

## Concurrency lock

`encoder_params.sh` and `rename_plex.sh` each take their own exclusive, non-blocking `flock` on the directory they operate on — `OUTPUT_DIR` for the encoder, the target directory for the renamer — as `<dir>/.media.lock`, immediately after validating that directory exists. A second run against the same directory, from any invocation path (the wrappers, or either script called directly), exits immediately with an error instead of racing. The lock releases automatically when the process exits, including on Ctrl-C.

Both scripts use the same lock filename convention, so a rename and an encode pointed at the same directory block each other too — not just same-script collisions. Runs against different directories are unaffected and can run concurrently.

`config.sh` and the four wrappers contain no locking logic — they're path/flag plumbing only. Either script can be run standalone, without going through a wrapper, and is still protected.

## Centralized language table

`lang_table.tsv` is the single source of truth for every language code, alias, and display label used across the project — add a language once here and it's picked up everywhere:

- `encoder_params.sh` sources `lang_table.sh` for its bash-side sidecar matching (`LANG_TABLE`, `LANG_3TO2`, `LANG_LABEL_BASH`), and its Python probe step reads `lang_table.tsv` directly for embedded-track display labels.
- `rename_plex.sh` sources `lang_table.sh` for its `LANG_ALIASES` lookup, used to normalize subtitle filename language tags (e.g. `.eng.srt` → `.en.srt`, `.fre.srt` → `.fr.srt`) to the 2-letter form `encoder_params.sh`'s sidecar matching expects.

Both `lang_table.sh` and `lang_table.tsv` must stay alongside the two scripts that source/read them — they resolve their own file locations relative to themselves, not the caller's working directory, so this works regardless of where a script is invoked from.

## `encoder_params.sh`

The core encoder is documented in full detail — every flag, the encoding/audio/subtitle decision logic, sidecar handling, logging format, and design rationale — in its own reference doc. It can be run directly (bypassing `config.sh` and the lock) for one-off jobs outside the standard `VIDEOS_BASE` layout; see that reference for the complete flag list.

## `rename_plex.sh`

Renames movie video and subtitle files into Plex's `Name (YYYY) {edition-X}` convention, normalizing subtitle language tags and modifiers (`cc`/`sdh`/`forced`) against `lang_table.sh` so files renamed here are guaranteed to match what `encoder_params.sh`'s sidecar discovery looks for. Files it can't confidently normalize (unrecognized language or modifier) are skipped and logged rather than guessed — see `-h` for full usage.