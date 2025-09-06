#!/bin/bash
# Arch Linux System Maintenance Script
set -euo pipefail
[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

# Detect if running interactively or by service
if [[ -n "${SYSTEMD_INVOCATION_ID-}" || ! -t 0 ]]; then
    INTERACTIVE=false
else
    INTERACTIVE=true
fi

# Basic logging function
log() {
    local msg="$1"
    local sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}

LOG_DIR="/var/log/sys-maintenance"
LOG_FILE="$LOG_DIR/$(date +'%Y-%m-%d').log"
mkdir -p "$LOG_DIR"
exec > >(tee -a "$LOG_FILE") 2>&1
log "System Maintenance Log - $(date)"
echo
log "Starting system maintenance..."

# Log date and time
log "$(date)"

# Refresh mirrorlist using reflector (if installed)
if command -v reflector &>/dev/null; then
    timestamp=$(grep '^# When:' /etc/pacman.d/mirrorlist | cut -d ':' -f2- | xargs)
    elapsed=$(( $(date -u +%s) - $(date -d "$timestamp" +%s) ))
    echo "Reflector last ran $elapsed seconds ago"

    two_hours=7200
    if (( elapsed > two_hours )); then
        # log "Reflector ran more than 2 hours ago."
        log "Updating mirrorlist with reflector..."
        reflector --latest 20 --threads 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null
    else
        log "Reflector ran less than 2 hours ago. Skipping..."
    fi
else
    log "Reflector not installed. Skipping mirrorlist update."
fi

# Update system packages
log "Updating official packages..."
pacman -Syu --noconfirm || log "No AUR updates available." o
log "Official packages are up to date." o

# Cleanup cache
log "Cleaning package cache..."
paccache -rk2 && log "Cache cleaned." o || log "Failed to clean cache" !

# If an AUR helper is available, use it to update AUR packages
update_aur() {
    local user="$1"
    for aur_helper in yay paru; do
        if sudo -u "$user" command -v "$aur_helper" &>/dev/null; then
            log "Updating AUR packages for user $user with $aur_helper..."
            sudo -u "$user" "$aur_helper" -Syu --noconfirm || log "No AUR updates available for $user." o
            log "Finished updating AUR packages for $user." o
            return
        fi
    done
    log "No AUR helper found for $user. Skipping..."
}

if $INTERACTIVE; then
    update_aur "${SUDO_USER:-$(logname)}"
else
    log "Updating AUR packages for all users with AUR helpers..."
    users=$(awk -F: '($3 >= 1000) && ($7 !~ /(nologin|false)$/) {print $1}' /etc/passwd)
    for user in $users; do
        log "Processing user: $user"
        update_aur "$user"
    done
fi

# Cleanup old logs (older than 7 days)
log "Cleaning up old logs..."
find "$LOG_DIR" -type f -mtime +7 -name "*.log" -exec rm -f {} \;

log "Old logs cleaned." o

log "System maintenance completed at $(date)." o