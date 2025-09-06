#!/bin/bash
set -euo pipefail

# aurinstall: Minimal AUR installer with multi-package support

NOCONFIRM=""
REINSTALL=0

CMD=$(basename "$0")
help_message="Usage: $CMD [--noconfirm] [-r|--reinstall] yay paru pkg3 ..."

# Parse flags
while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--reinstall)
            REINSTALL=1
            ;;
        --noconfirm)
            NOCONFIRM="--noconfirm"
            ;;
        -h|--help)
            echo $help_message
            exit 0
            ;;
        -*)
            echo "Unknown flag: $1"
            echo $help_message
            exit 1
            ;;
        *)
            packages+=("$1")
            ;;
    esac
    shift
done

# Process packages
for package in "${packages[@]}"; do
    echo "[*] Processing package: $package"
    
    # See if pacman already has the package installed (and optionally prompt reinstall)
    if pacman -Q "$package" &>/dev/null; then
        if [[ $REINSTALL -eq 1 ]]; then
            echo "[*] Reinstalling $package..."
            sudo pacman -R "$package" --noconfirm
        else
            echo "[o] $package already installed. Skipping."
            continue
        fi
    fi

    # Clean up and install
    tmpdir="/tmp/$CMD-$package"
    [[ -d "$tmpdir" ]] && rm -rf "$tmpdir"
    
    git clone "https://aur.archlinux.org/$package.git" "$tmpdir" || {
        echo "[x] Failed to clone $package"
        continue
    }
    
    cd "$tmpdir"
    makepkg -si $NOCONFIRM

    # Check path and version
    if command -v "$package" &>/dev/null; then
        echo "[o] Installed $package"
        "$package" --version || echo "(no '--version' output)"
    else
        echo "[?] '$package' installed, but no CLI binary found in PATH."
    fi
done