#!/bin/bash
# Minimal AUR installer with multi-package support
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
if (( EUID == 0 )); then
    _notif "Avoid running $CMD as root - switching to your user" "!"
    _hascmd sudo && [[ -n "${SUDO_USER:-}" ]] && exec sudo -u "$SUDO_USER" "$0" "$@" || _err "Cannot safely drop privileges; rerun as user"
fi

USAGE_MSG="Usage: $CMD [--noconfirm] [-r|--reinstall] yay paru pkg3 ..."
_usage() { echo "$USAGE_MSG" && exit 1; }

NOCONFIRM=false
REINSTALL=false
packages=()

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reinstall)
            REINSTALL=true ;;
        --noconfirm)
            NOCONFIRM=true ;;
        -h|--help)
            _usage ;;
        -*)
            _notif "Unknown flag: $1" !
            _usage
            ;;
        *)
            packages+=("$1") ;;
    esac
    shift
done

# Process packages
for package in "${packages[@]}"; do
    _notif "Processing package: $package"
    
    # See if pacman already has the package installed (and optionally prompt reinstall)
    if pacman -Q "$package" &>/dev/null; then
        if ! $REINSTALL; then
            _notif "$package already installed. Skipping." o
            continue
        fi
        _notif "Reinstalling $package..."
    fi

    # Clean up and install
    tmpdir="/tmp/$CMD-$package"
    rm -rf "$tmpdir"
    
    git clone "https://aur.archlinux.org/$package.git" "$tmpdir" || {
        _notif "Failed to clone $package" x
        continue
    }
    
    cd "$tmpdir"
    if $NOCONFIRM; then
        makepkg -si --noconfirm
    else
        makepkg -si
    fi
done