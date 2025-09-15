#!/bin/bash
# ufw-ipset: expand ipset members into real ufw rules
# Example:
#   sudo ./ufw-ipset allow proto tcp from ipset:cloudflare4 to any port 80,443 comment "cloudflare ipv4"

set -euo pipefail
[[ $EUID -ne 0 ]] && exec sudo "$0" "$@"
CMD=$(basename "$0")
ARGS=("$@")
IPSET_NAME=""

log() {
    local msg="$1"
    local sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}

err() {
    local msg=${1:-"no error message provided"}
    log "$CMD Error: $msg" "!"
    exit 1
}

# Detect ipset:NAME in args
for i in "${!ARGS[@]}"; do
    if [[ "${ARGS[$i]}" =~ ^ipset:(.+)$ ]]; then
        IPSET_NAME="${BASH_REMATCH[1]}"
        unset 'ARGS[$i]'   # drop it from the array
        break
    fi
done

[[ -z "$IPSET_NAME" ]] && err "No ipset:NAME found in arguments"

# Grab IPs from ipset
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    err "ipset '$IPSET_NAME' not found"
fi

IPS=$(ipset list "$IPSET_NAME" | awk '/Members:/ {found=1; next} found {print}')

[[ -z "$IPS" ]] && err "ipset '$IPSET_NAME' is empty"

# Expand: run ufw for each IP
for ip in $IPS; do
    log "Adding UFW rule for $ip"
    ufw "${ARGS[@]}" from "$ip"
done
