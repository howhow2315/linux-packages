#!/bin/bash
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

USAGE_MSG="Usage: $CMD [on|off] [interface]
Toggle the WireGuard connection for the specified interface.
By default, 'wg0' will be used."
_usage() { echo "$USAGE_MSG" && exit 1; }

# Safely escalate
_sudo() {
    if (( EUID != 0 )); then
        _hascmd sudo && exec sudo "$@" || _err "You need to be root to run this script"
    else
        "$@"
    fi
}

# Arguments
INTERFACE="${2:-wg0}"
ACTION="${1:-toggle}"

UPDOWN=$(systemctl is-active "wg-quick@$INTERFACE")

enable() {
    if [[ "$UPDOWN" == "inactive" ]]; then
        _notif "Attempting to bring up '$INTERFACE'..."
        if _sudo systemctl start "wg-quick@$INTERFACE"; then
            _notif "Connection to '$INTERFACE' established" o
            exit 0
        else
            _notif "Failed to start '$INTERFACE'" x
        fi
    else
        _notif "There is already a connection active to '$INTERFACE'" o
    fi
    exit 1
}

disable() {
    _notif "Attempting to bring down '$INTERFACE'..."
    if [[ "$UPDOWN" == "active" ]]; then
        if _sudo systemctl stop "wg-quick@$INTERFACE"; then
            _notif "Connection to '$INTERFACE' successfully terminated" o
            exit 0
        else
            _notif "Failed to stop '$INTERFACE'" x
        fi
    else
        _notif "There is already no connection active to '$INTERFACE'" o
    fi
    exit 1
}

_notif "WireGuard connection to '$INTERFACE' is $UPDOWN"
[[ "$UPDOWN" == "failed" ]] && _sudo systemctl restart "wg-quick@$INTERFACE"

case "$ACTION" in
    o|on) enable ;;
    f|off) disable ;;
    -h|--help|help) _usage ;;
    toggle|*) [[ "$UPDOWN" == "inactive" ]] && enable || disable ;;
esac
