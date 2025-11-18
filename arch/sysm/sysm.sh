#!/bin/bash
source /usr/lib/howhow/common.sh
_drop_privileges "$@"

_notif "Starting system maintenance..."

# Refresh mirrorlist
if _hascmd reflector; then
    timestamp=$(grep '^# When:' /etc/pacman.d/mirrorlist | cut -d ':' -f2- | xargs)
    elapsed=$(( $(date -u +%s) - $(date -d "$timestamp" +%s) ))

    hours=$(( elapsed / 3600 ))
    minutes=$(( (elapsed % 3600) / 60 ))
    seconds=$(( elapsed % 60 ))
    _notif "'reflector' last ran ${hours}h ${minutes}m ${seconds}s ago" i

    DAY_IN_SECONDS="$((60*60*24))"
    if (( elapsed > $DAY_IN_SECONDS )); then
        _notif "Updating mirrorlist with 'reflector' this may take a while..."
        _run_as_root reflector --score 25 --latest 25 --threads 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    fi
fi

# Update system packages
if _hascmd paru; then
    _notif "Updating system packages via paru..."
    paru
else
    _notif "Updating system packages via pacman..."
    _run_as_root pacman -Syu --noconfirm || _notif "System package update failed or no updates found." "!"
fi
_notif "System packages are up to date." o

if _hascmd flatpak; then
    _notif "Updating flatpack apps..."
    flatpak update -y

    _notif "Clearing flatpack cache..."
    flatpak uninstall --unused
    flatpak repair --user
fi

# Cleanup cache
if _hascmd paccache; then
    _notif "Cleaning package cache..."
    paccache -rk2 && _notif "Cache cleaned." o || _notif "Failed to clean cache" !
fi

_bell
_notif "$CMD complete!" o