# Kernel Panic on Boot: openrazer-driver-dkms Blocking Kernel Postinst

## Symptom

After a kernel/package update, rebooting into the newest kernel (`7.0.0-29-generic`) produced a kernel panic with `unknown-block(0,0)` — the kernel never identified a root device to mount. Booting the older, previously-working kernel (`6.17.0-35-generic`) via GRUB's Advanced Options continued to work normally.

## Initial hypotheses (in order of suspicion at the time)

1. Initramfs missing the NVMe driver, or a corrupted initramfs
2. GRUB pointing to a stale UUID/PARTUUID after a driver-reinstall-triggered kernel update
3. The NVMe SSD not being detected at all (connection or drive failure)

All three were reasonable given the symptom. None were correct.

## Actual root cause

`openrazer-driver-dkms` — a DKMS module for Razer peripheral drivers, with no corresponding hardware on this system (confirmed via `lsusb | grep -i razer`, no output) — failed to compile against both new kernels then present (`7.0.0-29-generic`, `7.0.0-28-generic`):

```
KERNELDIR=/lib/modules/7.0.0-29-generic/build make driver...(bad exit status: 2)
Error! Bad return status for module build on kernel: 7.0.0-29-generic (x86_64)
```

This DKMS failure happened inside `/etc/kernel/postinst.d/dkms`, one of several hook scripts `dpkg` runs as part of `linux-image-7.0.0-29-generic`'s post-installation sequence — **before** the `initramfs-tools` and `zz-update-grub` hooks that run later in that same sequence. When the `dkms` hook exited with an error, `run-parts` aborted the rest of the postinst chain for that package, and `linux-image-7.0.0-29-generic` was left in dpkg's `unconfigured` state. Whether initramfs generation and GRUB config update for that specific kernel actually ran to completion was left in doubt by this failure — the boot failure traced back to an incomplete kernel installation, not a fault in the initramfs/GRUB tooling itself.

Discovered via `apt install smartmontools` surfacing the same underlying dpkg breakage as a side effect (it triggered the same DKMS postinst hook, which failed the same way) — the panic and the failed `smartmontools` install were two symptoms of one broken package state, not two separate problems.

## Fix

```bash
# Confirm no Razer hardware is actually present
lsusb | grep -i razer

# Remove the driver with no hardware to support, clearing the DKMS failure point
sudo apt remove --purge openrazer-driver-dkms openrazer-daemon
sudo rm -f /var/crash/openrazer-driver-dkms.0.crash

# Let dpkg finish the postinst chain that previously aborted
sudo dpkg --configure -a
```

With the failing DKMS module gone, the same postinst chain completed cleanly on retry — `dkms: autoinstall for kernel 7.0.0-29-generic ...done`, followed by `initramfs-tools` regenerating the initrd and `zz-update-grub` finding both kernel images correctly.

## Verification

```bash
sudo update-initramfs -u -k all
sudo update-grub
ls -la /boot/initrd.img-7.0.0-29-generic          # sane size, not truncated
lsinitramfs /boot/initrd.img-7.0.0-29-generic | grep -i nvme   # driver present
dpkg -l | grep -E "linux-image-7.0.0-29|linux-headers-7.0.0-29"  # both "ii"
```

Rebooted directly into `7.0.0-29-generic` (not recovery mode) — boot succeeded. `nvidia-smi` confirmed the driver survived the kernel change; `dmesg` showed no new errors beyond expected/benign entries (self-signed module taint, ACPI `_PSL` evaluation warnings, one unexplained DIMM SPD read failure unrelated to this incident — see `System Architecture.md`'s Known Gaps).

## Prevention / lessons

- **A failed `apt install` for one package can leave unrelated packages broken.** The panic was diagnosed initially as an initramfs/GRUB problem because that's what the symptom looked like — the actual cause only surfaced because a later, unrelated `apt install smartmontools` hit the same dpkg breakage and produced a full error log to read. `sudo dpkg --configure -a` after *any* apt operation that reports errors is worth running immediately, not just when something later breaks visibly.
- **DKMS modules for hardware that isn't present are a standing risk, not a one-time fix.** `openrazer-driver-dkms` will fail the same way again on any future kernel it doesn't have a prebuilt module for, for as long as it's installed with nothing to actually drive. Removing it (done above) closes this permanently rather than requiring this fix to be repeated per kernel update.
- **`nvidia`'s DKMS build succeeded on both kernels throughout this incident** — this was never a recurrence of the driver issue in `NVIDIA_Driver_Fix_Summary.md`, despite being the same general failure class (DKMS module vs. new kernel). Worth checking which specific DKMS module failed (`dkms status`, or the `make.log` path in the apt error output) before assuming it's the same recurring problem.
- **Don't trust a plain reboot without a grace-period check when time-sensitive work is running elsewhere** (see the encoder-interruption discussion during this same incident) — Ctrl+C with visible cleanup confirmation is preferable to a bare `reboot`/`shutdown` when you want certainty rather than probability that in-flight work shut down cleanly.