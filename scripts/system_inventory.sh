#!/usr/bin/env bash
# system_inventory.sh — Read-only diagnostic pull for documenting the Ubuntu
# machine, its storage/RAID, and its network relationship to the Synology
# NAS. Every command here only reads state; nothing is modified.
#
# Run with sudo for full detail — dmidecode, smartctl, mdadm --detail, and
# fdisk -l all need root to return complete output:
#
#   sudo ./system_inventory.sh | tee system_inventory_$(date +%Y%m%d_%H%M).txt
#
# Paste the resulting file's contents back for the architecture outline.

set -uo pipefail

section() { echo; echo "=================================================="; echo "  $1"; echo "=================================================="; }

section "OS / KERNEL"
cat /etc/os-release 2>/dev/null
uname -a

section "CPU"
lscpu

section "MEMORY"
free -h
command -v dmidecode &>/dev/null && dmidecode -t memory || echo "(dmidecode unavailable — run with sudo)"

section "MOTHERBOARD"
command -v dmidecode &>/dev/null && dmidecode -t baseboard || echo "(dmidecode unavailable — run with sudo)"

section "GPU"
nvidia-smi 2>/dev/null || echo "(nvidia-smi not available)"
lspci -k 2>/dev/null | grep -A3 -i vga

section "ALL BLOCK DEVICES"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL,SERIAL

section "PARTITION TABLE DETAIL"
fdisk -l 2>/dev/null || echo "(requires sudo)"

section "MOUNTED FILESYSTEMS"
df -hT

section "MOUNT DETAIL FOR THE VIDEOS PATH SPECIFICALLY"
echo "--- findmnt on the path itself (only prints if it IS a mount point) ---"
findmnt /home/patrick/Videos 2>/dev/null
echo "--- findmnt -T (resolves which underlying mount actually backs this path) ---"
findmnt -T /home/patrick/Videos

section "PERSISTENT MOUNTS (/etc/fstab)"
cat /etc/fstab

section "SOFTWARE RAID — mdadm"
cat /proc/mdstat 2>/dev/null || echo "(no /proc/mdstat — mdadm likely not in use)"
if command -v mdadm &>/dev/null; then
    for md in /dev/md*; do
        [[ -e "$md" ]] || continue
        echo "--- $md ---"
        mdadm --detail "$md" 2>/dev/null || echo "(requires sudo for full detail)"
    done
fi

section "SOFTWARE RAID / VOLUMES — ZFS (if in use)"
command -v zpool &>/dev/null && zpool status || echo "(zfs not installed)"
command -v zfs &>/dev/null && zfs list 2>/dev/null

section "SOFTWARE RAID / VOLUMES — btrfs (if in use)"
command -v btrfs &>/dev/null && btrfs filesystem show 2>/dev/null || echo "(btrfs tools not installed, or requires sudo)"

section "HARDWARE RAID CONTROLLER CHECK"
lspci 2>/dev/null | grep -i raid || echo "(no dedicated RAID controller detected on PCI bus)"

section "DISK HEALTH (SMART) — per physical disk"
for disk in $(lsblk -dno NAME 2>/dev/null | grep -E '^(sd|nvme)'); do
    echo "--- /dev/$disk ---"
    if command -v smartctl &>/dev/null; then
        smartctl -H "/dev/$disk" 2>/dev/null || echo "(requires sudo)"
        smartctl -a "/dev/$disk" 2>/dev/null | grep -E 'Model|Serial|Power_On_Hours|Reallocated_Sector|Pending_Sector|Uncorrectable'
    else
        echo "(smartctl not installed — sudo apt install smartmontools)"
    fi
done

section "NETWORK INTERFACES"
ip -brief a 2>/dev/null

section "NETWORK ROUTES"
ip route 2>/dev/null

section "ACTIVE NETWORK-FILESYSTEM MOUNTS (NFS/CIFS/SMB)"
mount | grep -E 'nfs|cifs' || echo "(no active NFS/CIFS mounts found — check /etc/fstab section above too)"

section "LAN NEIGHBOR CACHE (may reveal the NAS's IP/MAC if recently contacted)"
ip neigh 2>/dev/null

section "DEV TOOLCHAIN"
echo "--- shell scripting ---"
command -v bash &>/dev/null && bash --version | head -1
command -v shellcheck &>/dev/null && shellcheck --version | grep version: || echo "shellcheck: not installed"
echo "--- node / typescript (video-encoder's TS/GH-Pages workload) ---"
command -v node &>/dev/null && node -v || echo "node: not installed"
command -v npm &>/dev/null && npm -v || echo "npm: not installed"
command -v npx &>/dev/null && npx --no-install tsc -v 2>/dev/null || echo "tsc: not found locally/globally (npx --no-install prevents an unwanted download here)"
echo "--- other ---"
command -v python3 &>/dev/null && python3 --version || echo "python3: not installed"
command -v git &>/dev/null && git --version || echo "git: not installed"

section "DOCKER STATE"
docker ps -a 2>/dev/null || echo "(docker not available or permission denied — try sudo)"
docker network ls 2>/dev/null

section "OLLAMA MODEL LIST (if the ollama container is running)"
docker exec ollama ollama list 2>/dev/null || echo "(ollama container not running, or not named 'ollama')"

echo
echo "=================================================="
echo "Inventory complete."
echo "=================================================="