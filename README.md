# homelab

Personal infrastructure hub. Four independent repos as submodules — each clonable, versioned, and pushed on its own — pinned to specific commits here.

**Cloning this repo requires `--recurse-submodules`, or the four subdirectories will be empty:**
```bash
git clone --recurse-submodules <this-repo-url>
# already cloned without it?
git submodule update --init --recursive
```

```
.
├── README.md                  ← this file
├── .gitmodules                 tracks the 4 submodule URLs/branches
├── .gitignore                  backup archives, migration scratch dir, editor/OS cruft
├── scripts/
│   ├── submodule_ctl.sh                status / update-all / checkout-branches / bump <name>
│   ├── restructure_to_submodules.sh    one-time migration (folders → submodules) — historical, do not re-run
│   ├── restructure_to_hub.sh           earlier one-time migration (monolith → categorized folders) — historical, do not re-run
│   ├── lint.sh                         shellcheck across scripts — verify scope still matches post-submodule-split
│   └── .locks/
├── llm/           (submodule)  Ollama/Open WebUI stack, agent runtimes, creative RAG
├── nas/           (submodule)  DS220+ upgrade guide, NAS-transfer automation roadmap
├── system/        (submodule)  Canonical hardware/storage/network/Docker reference
└── plex/          (submodule)  Encoder/renamer workflow (renamed from video-encoder)
```

## Where to look for what

**Hardware, storage, network, or Docker facts** — `system/README.md` is canonical. Every other repo used to point here directly; per the isolation rule, no repo but this parent does that now — this table is the only place that reference lives.

**Encoding or renaming video files, Plex** — `plex/README.md`.

**Local LLM / agent runtimes / RAG** — `llm/README.md`.

**NAS / media library** — `nas/README.md`.

## Working with submodules

**Check what's changed across all four:**
```bash
./scripts/submodule_ctl.sh status
```

**Pull the latest `main` into every submodule:**
```bash
./scripts/submodule_ctl.sh update-all
```
This updates your local working copies only. To make the parent repo point at the new commits (so a fresh clone gets them too), commit the bump per submodule:
```bash
./scripts/submodule_ctl.sh bump llm
```

**Editing inside a submodule:** submodules land in detached HEAD after clone/update — this is normal git behavior, not a bug, but don't commit from there. Fix it first:
```bash
./scripts/submodule_ctl.sh checkout-branches
cd llm
# make changes, commit, push — normal git workflow inside llm/ from here
cd ..
git add llm
git commit -m "Bump llm submodule"
```

**Each submodule pins `main` in `.gitmodules`** — `git submodule update --remote` pulls from that branch specifically, not whatever HEAD happens to be.