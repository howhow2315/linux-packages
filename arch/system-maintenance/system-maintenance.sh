#!/bin/bash
# Arch Linux System Maintenance Script
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "[x] Please run $(basename "$0") as root."
    exit 1
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

# Update system packages
echo "[*] Updating official packages..."
pacman -Syu --noconfirm

orphans=$(pacman -Qtdq)
if [[ -n "$orphans" ]]; then
    echo "[*] Removing orphaned packages..."
    pacman -Rns $orphans
else
    echo "[o] No orphaned packages found."
fi

# If an AUR helper is available, use it to update AUR packages
update_aur() {
    local user="${SUDO_USER:-$(logname)}"
    for aur_helper in yay paru; do
        if command -v "$aur_helper" &>/dev/null; then
            echo "[*] Updating AUR packages with $aur_helper..."
            sudo -u "$user" "$aur_helper" -Syu --noconfirm
            return
        fi
    done
    echo "[*] No AUR helper found. Skipping AUR updates."
}
update_aur

# Check for critical journal errors (priority 3 or higher) since last boot
echo "[*] Checking critical errors from journal..."
journalctl --quiet -p 3 -b || echo "[o] No critical errors found."

# List failed systemd services
echo "[*] Checking for failed systemd services..."
systemctl --failed || echo "[o] No failed services."

# Run rootkit hunter
if command -v rkhunter &>/dev/null; then
    echo "[*] Running rkhunter..."
    rkhunter --update
    rkhunter --cronjob --report-warnings-only
fi

# Run chkrootkit
if command -v chkrootkit &>/dev/null; then
    echo "[*] Running chkrootkit..."
    chkrootkit
fi

# Fail2Ban status check
if systemctl is-active --quiet fail2ban; then
    echo "[*] Fail2Ban status:"
    fail2ban-client status
fi

# Refresh mirrorlist using reflector (if installed)
if command -v reflector &>/dev/null; then
    echo "[*] Updating mirrorlist with reflector..."
    reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
else
    echo "[*] Reflector not installed. Skipping mirrorlist update."
fi

echo "[o] System maintenance completed."

# Cleanup old logs (older than 7 days)
echo "[*] Cleaning up old logs..."
find "$LOG_DIR" -type f -mtime +7 -name "*.log" -exec rm -f {} \;

echo "[o] Old logs cleaned."