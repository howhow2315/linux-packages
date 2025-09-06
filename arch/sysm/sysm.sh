#!/bin/bash
# Arch Linux System Maintenance Script
set -euo pipefail

# Detect if running as root
if [[ $EUID -ne 0 ]]; then
    echo "[x] Please run $(basename "$0") as root."
    exit 1
fi

# Detect if running interactively or by service
if [[ -n "${SYSTEMD_INVOCATION_ID-}" || ! -t 0 ]]; then
    INTERACTIVE=false
else
    INTERACTIVE=true
fi

LOG_DIR="/var/log/sys-maintenance"
LOG_FILE="$LOG_DIR/$(date +'%Y-%m-%d').log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "[*] System Maintenance Log - $(date)"
echo
echo "[*] Starting system maintenance..."

# Log date and time
echo "[*] $(date)"

# Refresh mirrorlist using reflector (if installed)
if command -v reflector &>/dev/null; then
    timestamp=$(grep '^# When:' /etc/pacman.d/mirrorlist | cut -d ':' -f2- | xargs)
    elapsed=$(( $(date -u +%s) - $(date -d "$timestamp" +%s) ))
    echo "Reflector last ran $elapsed seconds ago"

    two_hours=7200
    if (( elapsed > two_hours )); then
        # echo "[*] Reflector ran more than 2 hours ago."
        echo "[*] Updating mirrorlist with reflector..."
        reflector --latest 20 --threads 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null
    else
        echo "*] Reflector ran less than 2 hours ago. Skipping..."
    fi
else
    echo "[*] Reflector not installed. Skipping mirrorlist update."
fi

# Update system packages
echo "[*] Updating official packages..."
pacman -Syu --noconfirm || echo "[o] No AUR updates available."
echo "[o] Official packages are up to date."

# Cleanup cache
echo "[*] Cleaning package cache..."
paccache -rk2 && echo "[o] Cache cleaned." || echo "[!] Failed to clean cache"

# If an AUR helper is available, use it to update AUR packages
update_aur() {
    local user="$1"
    for aur_helper in yay paru; do
        if sudo -u "$user" command -v "$aur_helper" &>/dev/null; then
            echo "[*] Updating AUR packages for user $user with $aur_helper..."
            sudo -u "$user" "$aur_helper" -Syu --noconfirm || echo "[o] No AUR updates available for $user."
            echo "[o] Finished updating AUR packages for $user."
            return
        fi
    done
    echo "[*] No AUR helper found for $user. Skipping..."
}

if $INTERACTIVE; then
    update_aur "${SUDO_USER:-$(logname)}"
else
    echo "[*] Updating AUR packages for all users with AUR helpers..."
    users=$(awk -F: '($3 >= 1000) && ($7 !~ /(nologin|false)$/) {print $1}' /etc/passwd)
    for user in $users; do
        echo "[*] Processing user: $user"
        update_aur "$user"
    done
fi

# Cleanup old logs (older than 7 days)
echo "[*] Cleaning up old logs..."
find "$LOG_DIR" -type f -mtime +7 -name "*.log" -exec rm -f {} \;

echo "[o] Old logs cleaned."

echo "[o] System maintenance completed at $(date)."