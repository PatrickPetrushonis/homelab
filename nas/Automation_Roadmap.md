# NAS Automation Roadmap

**Status: not started. No timeline.**

Current state: batch-encoded output moves to the Synology DS220+ (which runs Plex and hosts the permanent media library — see `SYSTEM_ARCHITECTURE.md`) via a manual mount today, not a persistent one — nothing in `/etc/fstab`, no scripted transfer. This is intentional for the foreseeable future, not permanent. Automation is planned but deliberately deprioritized behind getting the local Linux environment (system tooling, `video-encoder`, local LLM/CLI setup) into a solid state first.

This file exists so that intent isn't lost or re-litigated later — not as a plan.

---

## When this gets picked up

Revisit after:
- `video-encoder`'s scripts are stable and in regular use (largely true already)
- The local LLM/CLI tooling (Vibe CLI + Ollama) is set up and in use
- The repo restructure into a multi-domain hub is done

No other trigger condition is defined. This section should be rewritten, not appended to, once real work starts.

## Open questions to resolve before any implementation work begins

These were flagged during initial planning and never answered — answer them here when this phase actually starts, don't guess ahead of that point:

1. **Scope**: does automation mean *this repo* drives NAS transfers (SSH/rsync/API calls out to the DS220+), or does it mean Synology's own scheduled tasks (DSM Task Scheduler) automate the NAS side independently, with this repo just documenting/coordinating rather than executing?
2. **Trigger model**: cron, systemd timer, or manually invoked (matching the deliberate no-automatic-anything pattern already used in `encoder_params.sh`/`rename_plex.sh` — dry-run-first, explicit flags, no silent background jobs)?
3. **Secrets handling**: if SSH-based, NAS credentials/keys are a new category of concern this repo hasn't had to deal with. Storage and rotation approach needs to be decided explicitly, not improvised at implementation time.
4. **What actually moves**: is this archiving `ARCHIVE_DIR` (`config.sh`'s `-M` output) to the NAS, backing up `BACKUP_DIR`, or something else entirely? Not yet defined.
5. **Plex/NAS safety — hard requirement, not a nice-to-have**: whatever this ends up being must not disrupt Plex or the NAS array. Concretely, that means at minimum: never write directly into a path Plex is actively scanning/serving from (copy-to-temp-then-atomic-move, same pattern `encoder_params.sh` already uses for local output); never touch a file mid-transfer in a way Plex's library scanner could pick up a partial file; avoid triggering unnecessary full library rescans; and avoid saturating the NAS during active playback. `encoder_params.sh`'s existing `archive_output()` (cp + size-verify + rm, not a raw overwrite) is the template to extend from, not reinvent.

## Hard requirement (not a design preference)

**This is the actual constraint driving this whole roadmap's existence, stated explicitly so it survives being reread months from now:** automation here must never risk the Plex library or the NAS array itself — no partial-file exposure to Plex's scanner, no direct overwrite of files Plex may have open, no write pattern that could corrupt the array under a bad interrupt. If a specific proposed implementation can't clearly satisfy this, it doesn't ship, regardless of how much of the rest of this roadmap is otherwise ready.

## Non-goals (for now)

- No code in this repo should reference or assume NAS connectivity until this roadmap is actually started.
- No changes to `config.sh`/`ARCHIVE_DIR`/`BACKUP_DIR` semantics on the strength of this file alone.