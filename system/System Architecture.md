# System Architecture

Canonical reference for this machine's hardware, storage, network, and running services. Sourced from `system_inventory.sh` output (same directory) — initial pass 2026-08-23, `sudo` rerun same day filling in privileged detail. `NVIDIA_Driver_Fix_Summary.md` (same directory) and `../llm/Ollama_Docker_Debug_Reference.md` point here for hardware facts instead of duplicating them — update this file when hardware/config changes, not the others.

---

## Machine

| Component | Detail |
|---|---|
| Hostname | PATRICK-PC |
| OS | Ubuntu 24.04.4 LTS (Noble Numbat) |
| Kernel | 7.0.0-29-generic |
| CPU | AMD Ryzen 9 5950X, 16C/32T |
| GPU | NVIDIA GeForce RTX 3060 (GA106), 12288MiB VRAM, driver 580.173.02 |
| Motherboard | Gigabyte X570S AORUS PRO AX |
| RAM | 64GB (4× 16GB DDR4, Corsair Vengeance CMW32GX4M2D3600C18) |

Board supports up to 128GB across 4 DIMM slots; all 4 are populated at 16GB each, so 64GB is simply what's installed — no missing or unseated modules.

**Worth acting on:** these DIMMs are rated for 3600 MT/s (per part number) but `dmidecode` reports them running at **2133 MT/s** — JEDEC base speed, meaning XMP/DOCP isn't enabled in BIOS. On Ryzen, memory clock drives the Infinity Fabric clock (FCLK), so this is a real, uncomplicated performance loss across CPU-bound work generally, including ffmpeg encoding — not just a memory-bandwidth footnote. Enabling DOCP/XMP in BIOS (UEFI setup, usually under Tweaker/Advanced Frequency Settings on this board) to run at the rated 3600 MT/s is a genuine free performance recommendation with no downside beyond a stability check after enabling it.

Onboard Ethernet (RTL8111EPV) is disabled in firmware — `enp6s0`, the interface actually carrying traffic, is the board's second/AX-series NIC, not this one. Not an issue, just worth noting so the disabled status doesn't read as a fault if seen again.

---

## Storage

| Device | Size | Role |
|---|---|---|
| `nvme0n1` (Kingston SFYRD4000G) | 3.6TB | OS + root filesystem (`/`), EFI boot partition |
| `sda` (Seagate ST8000DM004-2CX188) | 7.3TB | RAID 1 member (`md0`) |
| `sdb` (Seagate ST8000DM004-2CX188) | 7.3TB | RAID 1 member (`md0`) |

### `/raid` — the video-encoder working array

```
/home/patrick/Videos → /raid → /dev/md0 (ext4) → mdadm RAID 1 (sda + sdb)
```

- Software RAID via `mdadm`, not hardware, not ZFS/btrfs
- Created 2025-05-02, currently `clean`, both devices active, 0 failed, 0 spare — 87,797 events, no gaps in that count indicating no unlogged drops
- Status at last check: `[UU]` — both members active, no degradation
- 7.3TB total, ~60% used (4.1TB used / 2.9TB free at this inventory)
- This is the filesystem behind `INPUT_DIR`/`OUTPUT_DIR`/`ARCHIVE_DIR`/`BACKUP_DIR` in `config.sh` (all derived from `VIDEOS_BASE=$HOME/Videos`, which resolves onto this array)

### SMART health (confirmed 2026-08-23)

| Drive | Health | Power-on hours | Temp | Notes |
|---|---|---|---|---|
| `sda` (ZCT36EQ0) | PASSED | 28,787h | 55°C | Reallocated/Pending/Uncorrectable sectors all 0. `Airflow_Temperature_Cel` WORST (038) sits below THRESH (040) — a past temperature-attribute dip, marked `In_the_past`, 17 events recorded. Currently passing (VALUE 045 > THRESH 040); not actionable now, but this is the older/hotter/higher-hours member of the pair — worth knowing if repositioning drives for airflow later. |
| `sdb` (ZR134VBP) | PASSED | 23,033h | 52°C | Reallocated/Pending/Uncorrectable sectors all 0. No attribute-level flags. |
| `nvme0n1` | PASSED | 19,024h | 52°C (75°C secondary sensor) | Available Spare 100%, 6% used, 0 media/data integrity errors — no wear concern. `Unsafe Shutdowns: 38` corroborates the forced-shutdown history in `NVIDIA_Driver_Fix_Summary.md`. 662 logged errors are all `Invalid Field in Command` — unsupported admin commands rejected by firmware, not hardware faults (the same error class `smartctl` itself hit trying to read this drive's self-test log). |

Both HDDs' `Raw_Read_Error_Rate`/`Hardware_ECC_Recovered` raw values look large (100M+) but use Seagate's vendor-specific counter encoding — the normalized VALUE/THRESH columns are what matter, and both pass comfortably. No action needed on any of the three drives; nothing here indicates near-term failure risk.

### Two commented-out `/etc/fstab` entries (`/media/HDD1`, `/media/HDD2`)

Reference different UUIDs than the current `/raid` array — leftover from a prior local-disk layout, predating the current RAID 1 setup. Inactive; harmless to leave commented, safe to remove if the old UUIDs are confirmed unused elsewhere.

---

## Network

| Interface | Address | Role |
|---|---|---|
| `enp6s0` | 192.168.86.26/24 | Primary LAN |
| `tun0` | 10.6.18.250/24 | Active VPN tunnel |
| `docker0` | 172.17.0.1/16 | Docker bridge network |
| `wlp5s0` | — | Present, down |
| `virbr0` | 192.168.122.1/24 | libvirt bridge, down |

No NFS/CIFS mounts active; nothing in `/etc/fstab` references network storage.

### Synology DS220+ NAS

**Role: permanent media library and Plex host.** Encoded video lives here long-term and Plex itself runs here, serving playback to clients over the LAN — this machine's own `/raid` is transient encoder working space, not the library. Full rationale in `../nas/NAS_DS220_Upgrade_Guide.md`.

**No persistent or automated mount to this machine** — nothing in `/etc/fstab`, no scripted transfer from the encoder/rename scripts. Batch-encoded output moves over via a manual mount when needed; `system_inventory.sh` showing no active mount just means it wasn't mounted at that moment, not that the workflow doesn't exist. Automating that transfer is a planned future phase, timeline undefined, after the local Linux environment is in a solid state.

---

## Docker

| Container | Image | Status | Ports |
|---|---|---|---|
| `ollama` | ollama/ollama | Up | 11434→11434 |
| `open-webui` | ghcr.io/open-webui/open-webui:main | Up (healthy) | 3000→8080 |

Both containers' writable overlay layers live on `/` (the NVMe), confirmed via mounted overlay filesystems — not on `/raid`. Correct placement: container I/O stays on the fast drive, the HDD array is reserved for media.

See `Ollama_Docker_Debug_Reference.md` for model details and offload configuration.

---

## Dev Toolchain

Confirmed 2026-08-23 via `system_inventory.sh`'s Dev Toolchain section (added this session — first real data point):

| Tool | Version |
|---|---|
| bash | 5.2.21 |
| node | v22.21.0 |
| npm | 10.9.4 |
| python3 | 3.12.3 |
| git | 2.43.0 |
| shellcheck | not installed (`lint.sh` in this repo installs + runs it) |
| tsc | not found via global/npx lookup — check from inside the actual TS project directory (`npx tsc -v`) for a real answer; this repo isn't that project, so "not found" here doesn't mean TypeScript isn't set up where it's actually used |

---

## Known gaps

None outstanding. Motherboard, DIMM detail, full `mdadm --detail`, partition table, and SMART health on all three drives are all confirmed above as of the 2026-08-23 inventory + follow-up checks.

One minor unexplained item from a `dmesg` review during this pass, not urgent: `ee1004 2-0051: Failed to select page 0 (-6)` — the kernel driver that reads DIMM SPD (timing/config) EEPROM data failed to access one module's data at boot. Thematically adjacent to the RAM-speed finding above (both touch DIMM SPD), but no confirmed causal link. Worth a glance if it recurs after the XMP/DOCP change or shows up again in a future boot log; not acted on yet.