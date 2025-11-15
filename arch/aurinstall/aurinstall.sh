#!/bin/bash
# Minimal AUR installer with multi-package support
source /usr/lib/howhow/common.sh

USAGE_ARGS+=("[--noconfirm]" "[-r|--reinstall]" "yay" "paru" "pkg3" "...")

if _is_root; then
    _notif "Avoid running $CMD as root — switching to your user" "!"
    _drop_privileges "$@"
fi

# Defaults
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
    if _silently pacman -Q "$package"; then
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