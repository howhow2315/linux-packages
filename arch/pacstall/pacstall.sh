#!/bin/bash
[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"

CMD=$(basename "$0")
help_message="Usage: $CMD [operation] [options] [package(s)]...
Wrapper behavior:

Defaults to -S (sync/install) if no operation is given

--noconfirm is added automatically in non-interactive use (unless already passed)"

prompt_help() {
    echo "$help_message"
    echo
    echo "Below is 'pacman --help'. This script wraps the entirety of pacman, so every operation here is usable"
    pacman --help
    exit 0
}

# Defaults
operations=()
packages=()
noconfirm_present=false
auto_noconfirm=false

# Detect non-interactive use (e.g. script, pipe)
if [[ ! -t 0 || ! -t 1 ]]; then
    auto_noconfirm=true
fi

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --noconfirm)
            noconfirm_present=true
            packages+=("$1") ;; # pass through to pacman
        -h|--help)
            prompt_help ;;
        -?*)
            operations+=("$1") ;;
        *)
            packages+=("$1") ;;
    esac
    shift
done

# Default operation to -S if none given
if [[ ${#operations[@]} -eq 0 ]]; then
    operations=("-S")
fi

# Build pacman command
cmd=(pacman "${operations[@]}")

# Auto-add --noconfirm only if not already present
if $auto_noconfirm && ! $noconfirm_present; then
    cmd+=("--noconfirm")
fi

cmd+=("${packages[@]}")

exec "${cmd[@]}"