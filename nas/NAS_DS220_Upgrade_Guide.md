# DS220+ RAID 1 Upgrade: 8TB to 16TB

**Role: permanent media library and Plex host.** This NAS is where the encoded video library actually lives long-term and where Plex itself runs, serving playback to clients. The local Ubuntu machine's `/raid` (2×8TB, mdadm RAID 1) is *transient* working space for the encoder pipeline — raw input, in-progress encodes, archived output — not a growing library; content moves off it by design, so it doesn't need to scale with the library. This NAS does, which is the entire point of this upgrade: standard media-server capacity growth as the library grows, unrelated to anything on the encoding side.

Putting Plex here rather than on the encoding workstation also separates the two very different CPU-cost profiles: transcoding (expensive, occasional) stays on the machine that has the Ryzen 9 5950X / RTX 3060 to spare for it; serving already-compatible H.264 output to clients (cheap, near-continuous, direct-play in the common case since that's what the encoder pipeline is built to produce) stays on the NAS's much lighter hardware.

**No persistent or automated mount** — nothing in `/etc/fstab`, no scripted transfer. Batch-encoded output moves over via a manual mount when needed (not active at the moment `system_inventory.sh` happened to snapshot the system, which is why that scan showed no active mounts — it's an ad-hoc step, not a nonexistent one). Automating that manual step is a planned future phase, timeline undefined, after the local Linux environment is in a solid state.

## Prerequisites

- [ ] Verify array health in Storage Manager (must show "Normal")
- [ ] Back up critical data to separate location
- [ ] Have both 16TB drives ready (WD Red Plus, Seagate IronWolf, or compatible)
- [ ] Check drive health: Storage Manager → HDD/SSD (note power-on hours)
- [ ] Stop non-essential Docker containers/packages to reduce CPU load

## Process Overview

**Timeline: 1-3 days total**
- Drive 1 rebuild: 8-24 hours
- Drive 2 rebuild: 8-24 hours  
- Volume expansion: 2-6 hours

**Critical Rules:**
- Replace ONE drive at a time only
- Wait for complete rebuild before touching second drive
- Don't power off during rebuilds
- Array is vulnerable (no redundancy) until each rebuild completes

---

## Step 1: Replace First Drive

**Physical swap:**
1. Shut down DS220+ completely (DSM → Power → Shutdown)
2. Wait for all lights off
3. Pop front panel, slide out Bay 1 (left) tray
4. Remove 8TB drive, install first 16TB drive
5. Reinsert tray, replace front panel
6. Power on

**Initiate rebuild:**
1. Log into DSM
2. Storage Manager will show degraded array warning
3. Navigate to Storage Pool
4. Click the degraded pool
5. Select the new uninitialized drive
6. Click "Repair"
7. DSM automatically formats and begins rebuild

**Monitor:**
- Storage Manager shows rebuild progress percentage
- Estimated time remaining updates
- Status must reach "Normal" before proceeding

---

## Step 2: Replace Second Drive

**After Drive 1 rebuild shows "Normal" status:**

**Physical swap:**
1. Shut down DS220+
2. Swap Bay 2 (right) 8TB for second 16TB
3. Power on

**Initiate rebuild:**
1. Storage Manager → degraded pool
2. Select new drive → Repair
3. Wait for second rebuild to complete

---

## Step 3: Expand Volume

**After Drive 2 rebuild shows "Normal" status:**

1. Storage Manager → Storage Pool
2. Select your pool → Action → Change RAID Type (skip if already maximum)
3. Storage Manager → Volume
4. Select volume → Action → Expand
5. Allocate new space (16TB total now available)
6. Wait for expansion process (2-6 hours)

---

## Verification

- [ ] Storage Pool shows "Normal" status
- [ ] Volume shows ~14.5TB usable (16TB minus filesystem overhead)
- [ ] All services/packages restart successfully
- [ ] File access works normally

---

## If Something Goes Wrong

**Array won't rebuild:**
- Check drive compatibility on Synology's list
- Verify drive detected in Storage Manager → HDD/SSD
- Check DSM logs: Log Center → System

**Power loss during rebuild:**
- Rebuild resumes automatically on boot
- If corruption occurs, restore from backup

**Performance issues after upgrade:**
- Reboot DS220+ after all processes complete
- Re-enable stopped services gradually

---

## Notes

- NAS remains accessible during rebuilds but slower
- Avoid heavy CPU tasks (Plex transcoding, etc.) during process
- RAID 1 protects against drive failure, not data corruption/deletion
- Backup is mandatory—RAID is not backup
- Drive formatting happens automatically in DSM (ext4/Btrfs)
- Either bay can be replaced first (recommend Bay 1 for consistency)