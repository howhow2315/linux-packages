#!/bin/bash

if [[ -z "$2" ]]; then
    INTERFACE="wg0"
else
    INTERFACE="$1"
    shift
fi
UPDOWN=$(systemctl is-active wg-quick@$INTERFACE)

usage() {
    echo "Usage: $(basename "$0") [on|off]"
    echo "Toggle the WireGuard connection for the specified interface."
    echo "By default, 'wg0' will be used as the network interface."
}

enable() {
    if [[ "$UPDOWN" == "inactive" ]]; then
        echo "[*] Attempting to toggle connection to '$INTERFACE' on"
        if sudo systemctl start wg-quick@$INTERFACE; then
            echo "[o] Connection to '$INTERFACE' established"
            exit 0
        else
            echo "[x] Failed to establish a connection to '$INTERFACE'"
        fi
    else
        echo "[o] There is already an connection active to '$INTERFACE'"
    fi
    exit 1
}

disable() {
    echo "[*] Attempting to toggle connection to '$INTERFACE' off"
    if [[ "$UPDOWN" == "active" ]]; then
        if sudo systemctl stop wg-quick@$INTERFACE; then
            echo "[o] Connection to '$INTERFACE' successfully terminated"
            exit 0
        else
            echo "[x] Failed to terminate the connection to '$INTERFACE'"
        fi
    else
        echo "[o] There is already no connection active to '$INTERFACE'"
    fi
    exit 1
}

echo "[*] WireGuard connection to '$INTERFACE' is $UPDOWN"
[[ "$UPDOWN" == "failed" ]] && sudo systemctl restart wg-quick@$INTERFACE
case "$1" in
    o|on) enable ;;
    i|off) disable ;;
    -h|--help|help) usage || exit 0 ;;
    *) [[ "$UPDOWN" == "inactive" ]] && enable || disable ;;
esac