#!/bin/bash
# A simple pacman wrapper for shorthand inside scripts and basic usage
source /usr/lib/howhow/common.sh

_notif "Deprecated: Please use paru instead"

USAGE_ARGS+=("[operation]" "[options]" "[package(s)]")
USAGE_MSG="
Operations:
    pacstall {-h --help}

Wrapper behavior:
Defaults to -S (sync/install) if no operation is given
--noconfirm is added automatically in non-interactive use (unless already passed)

Below is 'pacman --help'. This script wraps the entirety of pacman, so every operation here is usable"
USAGE_CMDS+=("pacman --help")

# If no arguments are specified it'll just route to pacmans error msg "error: no targets specified."
[[ $# -eq 0 ]] && _usage

operations=()
packages=()

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            _usage ;;
        -?*)
            operations+=("$1") ;;
        *)
            packages+=("$1") ;;
    esac
    shift
done

# Default to -S operation if none are given
[[ ${#operations[@]} -eq 0 ]] && operations=("-S")

# Add "--noconfirm" if non-interactive and not already present
! _is_terminal && ! _contains_arg "--noconfirm" "${operations[@]}" && operations+=("--noconfirm")

# Build pacman command
cmd+=("${operations[@]}" "${packages[@]}")

_run_as_root pacman "${cmd[@]}"
