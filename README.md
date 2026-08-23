# homelab

Personal infrastructure hub: local Linux workstation, video-encoder pipeline, local LLM tooling, NAS/media hosting, and web project references.

```
.
├── README.md                          ← this file
├── system/
│   ├── System Architecture.md         Canonical hardware/storage/network/Docker reference
│   ├── system_inventory.sh            Read-only diagnostic pull (feeds System Architecture.md)
│   ├── NVIDIA_Driver_Fix_Summary.md   Current driver state + historical fix
│   ├── Kernel_Panic_Incident.md       openrazer-driver-dkms boot-panic root cause + fix
│   └── GMMK_RGB_Lighting_Shortcuts.md Keyboard reference
├── video-encoder/
│   ├── README.md                      Encoder/renamer workflow, flags, design notes
│   └── scripts/                       config.sh, encoder*.sh, rename*.sh, lang_table.*
├── llm/
│   └── Ollama_Docker_Debug_Reference.md   Ollama + open-webui setup, models, CPU offload
├── nas/
│   ├── NAS_DS220_Upgrade_Guide.md     DS220+ RAID 1 8TB→16TB upgrade procedure
│   └── Automation_Roadmap.md          NAS-transfer automation: status, open questions, hard requirements
└── web/
    └── React_TS_Vite_GHPages_Setup_Guide.md   Vite/TS/GH Pages setup, known regressions
```

---

## Where to look for what

**Hardware, storage, network, or Docker facts** — `system/System Architecture.md` is canonical. Every other doc points here instead of re-stating hardware facts; update it, not the others, when something changes.

**Encoding or renaming video files** — `video-encoder/README.md`. Workflow: `video-encoder/scripts/encoder_dry.sh` → `encoder.sh`, `rename_dry.sh` → `rename.sh`. `lint.sh` runs shellcheck across every script in the repo.

**Local LLM / coding-assistant setup** — `llm/Ollama_Docker_Debug_Reference.md`. Ollama + open-webui already running; model choice and CPU-offload configuration documented there.

**NAS / Plex** — `nas/NAS_DS220_Upgrade_Guide.md` for the physical upgrade procedure (states the NAS's actual role: permanent media library + Plex host, separate from the encoder's transient local working storage). `nas/Automation_Roadmap.md` for the current manual-transfer status and what has to be true before that becomes scripted — including the hard requirement that automation must never risk the Plex library or the NAS array.

**Known past incidents** — `system/NVIDIA_Driver_Fix_Summary.md`, `system/Kernel_Panic_Incident.md`. Both are the same failure class (a DKMS module breaking on a kernel update) with different specific culprits.

**Web project reference** — `web/React_TS_Vite_GHPages_Setup_Guide.md`. Vite is currently pinned below v8 pending resolution of a known Rolldown memory regression; check that doc before upgrading.

---

## Repo maintenance

- `restructure_to_hub.sh` (if still present at root) performed the initial move into this layout via `git mv`, preserving history. Re-running it is a no-op once everything's already in place — it skips anything not found at its old path.
- Cross-doc references use relative paths from each file's own location (e.g. `../nas/NAS_DS220_Upgrade_Guide.md` from `system/`). If you move a file, grep the rest of the repo for its old filename before assuming nothing points at it.