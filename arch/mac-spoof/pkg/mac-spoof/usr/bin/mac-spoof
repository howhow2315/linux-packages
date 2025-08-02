#!/bin/bash
# MAC Spoofing Toggle Script for NetworkManager
set -e

if [[ $EUID -ne 0 ]]; then
    echo "[x] Please run $0 as root."
    exit 1
fi

CONFIG_FILE="/etc/NetworkManager/conf.d/mac-spoof.conf"

print_status() {
    if [[ -f "$CONFIG_FILE" ]] && grep -q "# MAC Spoofing: ENABLED" "$CONFIG_FILE"; then
        echo "  [*] MAC Spoofing is ENABLED"
    else
        echo "  [*] MAC Spoofing is DISABLED"
    fi
}

# Parse flags
CMD_USAGE="Usage: $0 [-s|--status]"
while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--status)
            print_status
            exit 0
            ;;
        *)
            echo "[x] Unknown flag: $1"
            echo "$CMD_USAGE"
            exit 1
            ;;
    esac
    shift
done

print_status
echo
read -r -p "Would you like to (e)nable, (d)isable, or (c)ancel? [e/d/c]: " choice
choice="${choice,,}"

mkdir -p /etc/NetworkManager/conf.d/

case "$choice" in
    e)
        echo "[+] Enabling MAC spoofing..."
        cat <<EOF > "$CONFIG_FILE"
# MAC Spoofing: ENABLED
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=preserve
EOF
        ;;
    d)
        echo "[-] Disabling MAC spoofing..."
        cat <<EOF > "$CONFIG_FILE"
# MAC Spoofing: DISABLED
[device]
wifi.scan-rand-mac-address=no

[connection]
wifi.cloned-mac-address=permanent
ethernet.cloned-mac-address=permanent
EOF
        ;;
    *)
        echo "[x] Cancelled."
        exit 0
        ;;
esac

echo "[*] Restarting NetworkManager..."
systemctl restart NetworkManager

echo "[o] MAC spoofing state updated."