#!/bin/bash
# A simple pacman wrapper for shorthand inside scripts and basic usage
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
if (( EUID != 0 )); then
    if _hascmd sudo; then
        _notif "This script is running as root via sudo: '$0 $*'"
        exec sudo "$0" "$@"
    else
        _err "You need to be root to run this script"
    fi
fi

USAGE_MSG="Usage: $CMD [operation] [options] [package(s)]...
Wrapper behavior:

Defaults to -S (sync/install) if no operation is given

--noconfirm is added automatically in non-interactive use (unless already passed)

Below is 'pacman --help'. This script wraps the entirety of pacman, so every operation here is usable"
_usage() { echo "$USAGE_MSG" && pacman --help && exit 1; }

# If no arguments are specified it'll just route to pacmans error msg "error: no targets specified."
[[ $# -eq 0 ]] && _usage

# Defaults
operations=()
packages=()
noconfirm_present=false
auto_noconfirm=false
verbose=false

# Detect non-interactive use (e.g. script, pipe)
[[ ! -t 0 || ! -t 1 ]] && auto_noconfirm=true

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --noconfirm)
            noconfirm_present=true
            packages+=("$1") ;; # pass through to pacman
        -h|--help)
            _usage ;;
        -v|--verbose) 
            verbose=true ;;
        -?*)
            operations+=("$1") ;;
        *)
            packages+=("$1") ;;
    esac
    shift
done

# Default to -S operation if none are given
[[ ${#operations[@]} -eq 0 ]] && operations=("-S")

# Check if a basic sync operation is being run
if printf '%s\n' "${operations[@]}" | grep -Eq '^-S($|[[:space:]])'; then
    $verbose && _notif "Sync operation detected checking the freshness of your repositories"

    # Check each package to see if its last build date was within our last database sync for its repository to avoid 404 errors
    for pkg in "${packages[@]}"; do
        # Skip anything that isn’t a valid repo name
        [[ "$pkg" == ./* || "$pkg" == *.pkg.tar.* ]] && continue
                
        # query package info
        info=$(pacman -Si "$pkg" 2>/dev/null || true)
        [[ -z $info ]] && _notif "Skipping freshness check for '$pkg' (no package info found)" "!" && continue

        # extract repo and build date
        repo=$(awk -F': *' '/^Repository/ {print $2}' <<<"$info")
        build_date=$(awk -F': *' '/^Build Date/ {sub(/\s+\([^)]+\)$/, "", $2); print $2}' <<<"$info")
        [[ -z "$repo" || -z "$build_date" ]] && _notif "Skipping freshness check for '$pkg' (missing repo or build date)" "!" && continue

        # Get last sync date
        dbfile="/var/lib/pacman/sync/${repo}.db"
        [[ ! -f "$dbfile" ]] && _notif "Skipping freshness check for '$pkg' (missing database file for repo '$repo')" "!" && continue

        # Convert dates to seconds
        build_ts=$(date -d "$build_date" +%s 2>/dev/null || echo 0); (( build_ts == 0 )) && _notif "Unable to parse build date for '$pkg'" "!"
        db_ts=$(stat -c %Y "$dbfile")

        # Compare and sync if necessary
        if (( build_ts > db_ts )); then
            _notif "Repo '$repo' is stale (pkg newer than db), refreshing..." "~"
            pacman -Sy --noconfirm >/dev/null && _notif "Repository database updated" "~" || _err "Failed to refresh repositories for '$repo'"
            break
        else
            $verbose && _notif "Repo '$repo' is up-to-date for '$pkg'" "o"
        fi
    done
fi

# Build pacman command
cmd=(pacman "${operations[@]}")

# Add "--noconfirm" if non-interactive and not already present
$auto_noconfirm && ! $noconfirm_present && cmd+=("--noconfirm")

cmd+=("${packages[@]}")

$verbose && _notif "Executing: '${cmd[*]}'" "+"
exec "${cmd[@]}"