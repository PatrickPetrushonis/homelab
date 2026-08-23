# NVIDIA Driver Fix Summary

## Current State (as of 2026-08-23 inventory)

- **Driver running:** v580.173.02
- **GPU:** NVIDIA GeForce RTX 3060 (GA106), 12288MiB
- Driver has updated past the fix version below since the incident, most likely via unattended-upgrades. No issues currently observed.

---

## Historical Incident (resolved)

The section below documents a specific past incident and the fix that resolved it at the time. Kept for reference if the same failure mode recurs after a future forced shutdown — not current-state guidance.

### Issue
NVIDIA driver (nvidia-smi) failed to communicate with GPU after forced system shutdowns. Driver modules were corrupted or not loaded.

### Findings
- **GPU**: NVIDIA GeForce RTX 3060 (GA106)
- **Driver installed at the time**: nvidia-driver-580-open
- **Problem**: Kernel headers for the running kernel were missing
- **Error**: DKMS couldn't build driver modules without headers

### Root Cause
Forced shutdowns corrupted driver state. Subsequent reinstall attempt failed because the matching kernel headers weren't installed—the driver package requires headers to compile kernel modules via DKMS.

### Solution
1. Reinstalled driver package: `sudo apt install --reinstall nvidia-driver-580-open`
2. Installed missing kernel headers: `sudo apt install linux-headers-$(uname -r)`
3. DKMS automatically rebuilt driver modules for current kernel
4. Rebooted to load new modules
5. Verified with `nvidia-smi` showing driver v580.95.05 loaded

### Prevention
After kernel updates, ensure matching headers are installed before driver builds. The `linux-headers-generic-hwe-24.04` metapackage automatically installs headers for new kernels.

---

## If GPU Communication Fails Again

Same recovery steps as above apply regardless of the specific driver version in play:

```bash
sudo apt install --reinstall nvidia-driver-<version>
sudo apt install linux-headers-$(uname -r)
sudo reboot
nvidia-smi   # verify
```