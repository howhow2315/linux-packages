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

USAGE_MSG="Usage: $CMD [on|off|toggle] [interface]
Toggle the WireGuard connection for the specified interface.
By default, the interface 'wg0' will be used and toggled."
_usage() { echo "$USAGE_MSG" && exit 1; }

# Safely escalate
_sudo() {
    if (( EUID != 0 )); then
        _hascmd sudo && sudo "$@" || _err "You need to be root to run this script"
    else
        "$@"
    fi
    return 0
}

# Arguments
INTERFACE="${2:-wg0}"
ACTION="${1:-toggle}"

updown() {
    local state=$(systemctl is-active "wg-quick@$INTERFACE" || true)
    echo $state
}

enable() {
    if [[ "$(updown)" == "inactive" ]]; then
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
    if [[ "$(updown)" == "active" ]]; then
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

[[ "$(updown)" == "failed" ]] && _sudo systemctl restart "wg-quick@$INTERFACE"

# restart if service is stuck
if [[ "$(updown)" == "failed" ]]; then
    _notif "Restarting failed interface '$INTERFACE'..."
    _sudo systemctl restart "wg-quick@$INTERFACE"
fi

toggle() {
    local state=$(updown)
    _notif "WireGuard connection to '$INTERFACE' is $state"

    case "$state" in
        active)  disable ;;
        inactive|failed) enable ;;
        *) _notif "Unknown state: $state" "?" ;;
    esac
}
case "$ACTION" in
    -o|--on|o|on) enable ;;
    -i|--off|i|off) disable ;;
    -h|--help|h|help) _usage ;;
    -t|--toggle|t|toggle) toggle ;;
    *)
        INTERFACE="$ACTION"
        toggle
        ;;
esac