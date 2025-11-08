#!/bin/bash
# ufw-ipset: expand ipset members into real ufw rules
# Example:
#   sudo ./ufw-ipset allow proto tcp from ipset:cloudflare4 to any port 80,443 comment "cloudflare ipv4"

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

CMD=$(basename "$0")
ARGS=("$@")
IPSET_NAME=""
DIRECTION=""

# Detect `from ipset:NAME` or `to ipset:NAME`
for ((i=0; i<${#ARGS[@]}-1; i++)); do
    if [[ "${ARGS[$i]}" =~ ^(from|to)$ && "${ARGS[$((i+1))]}" =~ ^ipset:(.+)$ ]]; then
        DIRECTION="${ARGS[$i]}"
        IPSET_NAME="${ARGS[$((i+1))]#ipset:}"
        unset 'ARGS[$i]'
        unset 'ARGS[$((i+1))]'
        break
    fi
done
[[ -z "$IPSET_NAME" ]] && _err "No 'from ipset:<name>' or 'to ipset:<name>' found in arguments"

# Grab IPs from ipset
if ! ipset list "$IPSET_NAME" >/dev/null 2>&1; then
    _err "ipset '$IPSET_NAME' not found"
fi

IPS=$(ipset list "$IPSET_NAME" | awk '/Members:/ {found=1; next} found {print}')
[[ -z "$IPS" ]] && _err "ipset '$IPSET_NAME' is empty"

# Expand: run ufw for each member of the set
for ip in $IPS; do
    _notif "Changing ufw rule for $DIRECTION $ip"
    if ! output=$(ufw "${ARGS[@]}" "$DIRECTION" "$ip" 2>&1); then
        _err "$output"
    fi
done

_notif "UFW ipset changes successful" o
_notif "UFW verbose status: " i
ufw status verbose