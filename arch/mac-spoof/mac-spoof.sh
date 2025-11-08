#!/bin/bash
# MAC Spoofing Toggle Script for NetworkManager
source /usr/lib/howhow/common.sh
_require_root "$@"

USAGE_ARGS+=("[on|off|status|help]")

# Require at least one arg
[[ $# -eq 0 ]] && _usage

CONFIG_FILE="/etc/NetworkManager/conf.d/mac-spoof.conf"
ENABLED=false
[[ -f "$CONFIG_FILE" ]] && grep -q "# MAC Spoofing: ENABLED" "$CONFIG_FILE" && ENABLED=true

ENABLED_CONFIG="# MAC Spoofing: ENABLED
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=preserve"

enable() {
    _notif "Enabling MAC spoofing..." "+"
    mkdir -p /etc/NetworkManager/conf.d/
    echo "$ENABLED_CONFIG" > "$CONFIG_FILE"
}

DISABLED_CONFIG="# MAC Spoofing: DISABLED
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=permanent
ethernet.cloned-mac-address=permanent"

disable() {
    _notif "Disabling MAC spoofing..." "+"
    mkdir -p /etc/NetworkManager/conf.d/
    echo "$DISABLED_CONFIG" > "$CONFIG_FILE"
}

status() {
    local state="disabled"
    [[ "$ENABLED" == "true" ]] && state="enabled"
    _notif "MAC Spoofing is currently $state." o
}

case "${1,,}" in
    on|o) enable ;;
    off|i) disable ;;
    -s|--status|s|status) status && exit 0 ;;
    -h|--help|h|help) _usage ;;
    *)
        _notif "Unknown option: $1" "!"
        _usage
        ;;
esac

_notif "Restarting NetworkManager..."
systemctl restart NetworkManager && _notif "MAC spoofing state updated." o || _err "Failed to restart NetworkManager"
status
