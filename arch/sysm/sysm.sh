#!/bin/bash
# Arch Linux System Maintenance Script
set -euo pipefail

_notif() {
    local msg="$1" sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}
CMD=$(basename "$0")
_err() {
    local msg="$1" code=${2:-1}
    _notif "$CMD ERROR: $msg" !
    exit "$code"
}
_hascmd() { command -v "$1" &>/dev/null; }
(( EUID != 0 )) && { _hascmd sudo && exec sudo "$0" "$@" || _err "You need to be root to run this script"; }

_notif "Starting system maintenance..."

# Refresh mirrorlist
if _hascmd reflector; then
    timestamp=$(grep '^# When:' /etc/pacman.d/mirrorlist | cut -d ':' -f2- | xargs)
    elapsed=$(( $(date -u +%s) - $(date -d "$timestamp" +%s) ))
    # _notif "Reflector last ran $elapsed seconds ago" i

    TWO_HOURS="$((60*60*2))"
    if (( elapsed > TWO_HOURS )); then
        _notif "Updating mirrorlist with reflector this may take a while..."
        reflector --latest 20 --threads 5 --protocol https --sort rate --save /etc/pacman.d/mirrorlist &>/dev/null
    fi
fi

# Update system packages
_notif "Updating official packages..."
pacman -Syu --noconfirm || _notif "Official package update failed or no updates found." "!"
_notif "Official packages are up to date." o

# Cleanup cache
_notif "Cleaning package cache..."
paccache -rk2 && _notif "Cache cleaned." o || _notif "Failed to clean cache" !

# If an AUR helper is available, use it to update AUR packages
update_aur() {
    local user="$1"
    for aur_helper in yay paru; do
        if sudo -u "$user" command -v "$aur_helper" &>/dev/null; then
            _notif "Updating AUR packages for user $user with $aur_helper..."
            if sudo -u "$user" "$aur_helper" -Syu --noconfirm; then
                _notif "Finished updating AUR packages for $user." o
            else
                _notif "No AUR updates available for $user." o
            fi
            return 0
        fi
    done
    _notif "No AUR helper found for $user. Skipping..."
}

# Detect if running interactively or by service
INTERACTIVE=false
[[ -t 0 && -t 1 ]] && INTERACTIVE=true

if $INTERACTIVE; then
    update_aur "${SUDO_USER:-$(logname)}"
else  # Example: Running via systemd and acting as pure root
    _notif "Updating AUR packages for all users with AUR helpers..."
    users=$(awk -F: '($3 >= 1000) && ($7 !~ /(nologin|false)$/) {print $1}' /etc/passwd)
    for user in $users; do
        _notif "Processing user: $user"
        update_aur "$user"
    done
fi

_notif "$CMD complete!" o