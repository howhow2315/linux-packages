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

[[ $EUID -ne 0 ]] && {
    if command -v sudo &>/dev/null; then
        exec sudo "$0" "$@"
    else
        _err "You need to be root to run this script"
    fi
}

ACTION="${1:-}"
CLIENT_NAME="${2:-}"

SCRIPT_CMD=$(basename "$0")

KEY_DIR="/etc/wireguard/keys"
CONF_DIR="/etc/wireguard/clients"
PEER_DIR="/etc/wireguard/peers"
WG_BASE="/etc/wireguard/wg0.base.conf"
WG_CONF="/etc/wireguard/wg0.conf"

WG_PORT="51820"

SERVER_PUBLIC_IP="129.80.84.37"
SERVER_ENDPOINT="${SERVER_PUBLIC_IP}:${WG_PORT}"
WG_INTERFACE="wg0"

function usage() {
    echo "Usage:"
    echo "  $SCRIPT_CMD add <client-name> [client-ip]"
    echo "  $SCRIPT_CMD remove <client-name>"
    echo "  $SCRIPT_CMD list"
    exit 1
}

function rebuild_wg0() {
    echo "[*] Rebuilding wg0.conf..."
    if [[ ! -s "$WG_BASE" ]]; then
        echo "[!] Base config ($WG_BASE) is missing or empty. Aborting." >&2
        exit 1
    fi

    cat "$WG_BASE" > "$WG_CONF"
    for peer in "$PEER_DIR"/*.conf; do
        [[ -s "$peer" ]] && { echo >> "$WG_CONF"; cat "$peer" >> "$WG_CONF"; }
    done

    # Clear out all stale peers:
    echo "[*] Refreshing peers..."
    sudo wg-quick down wg0 && sudo wg-quick up wg0

    # Reload WireGuard
    wg addconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")

    echo "[o] wg0.conf has been rebuilt."
}

# REMOVE CLIENT
if [[ "$ACTION" == "remove" ]]; then
    [[ -z "$CLIENT_NAME" ]] && usage

    echo "[-] Removing client: $CLIENT_NAME"

    # Remove peer block from wg0.conf
    sudo sed -i "/# ${CLIENT_NAME}/,+2d" "$WG_CONF"

    # Remove keys and config
    rm -f "$KEY_DIR/${CLIENT_NAME}_private.key"
    rm -f "$KEY_DIR/${CLIENT_NAME}_public.key"
    rm -f "$CONF_DIR/${CLIENT_NAME}.conf"
    rm -f "$PEER_DIR/${CLIENT_NAME}.conf"

    # Rebuild & Reload
    rebuild_wg0
    echo "[o] Client '$CLIENT_NAME' removed"
    exit 0
fi

# LIST CLIENTS
if [[ "$ACTION" == "list" ]]; then
    echo "[*] Existing clients:"
    for conf in "$CONF_DIR"/*.conf; do
        [[ -f "$conf" ]] || continue
        client=$(basename "$conf" .conf)

        # Get assigned IP
        ip=$(grep -oP 'Address\s*=\s*\K.*' "$conf")

        # Get public key
        pubkey=$(cat "$KEY_DIR/${client}_public.key" 2>/dev/null || echo "(missing key)")

        # Get WireGuard status if peer is loaded
        if wg show "$WG_INTERFACE" | grep -q "$pubkey"; then
            stats=$(wg show "$WG_INTERFACE" | awk -v key="$pubkey" '
                $1 == "peer:" && $2 == key { in_block = 1; next }
                in_block && $1 == "endpoint:" { endpoint = $2 }
                in_block && $1 == "allowed" { allowed=$3 }
                in_block && $1 == "latest" {
                    if ($3 == "ago") {
                        handshake = $2 " ago"
                    } else {
                        handshake = $3 " " $4
                    }
                }
                in_block && $1 == "transfer:" { rx=$2 " " $3; tx=$5 " " $6 }
                in_block && /^$/ { in_block = 0 }
                END {
                    if (handshake != "") {
                        print "     Status: connected"
                        print "         Endpoint: " endpoint
                        print "         Last handshake: " handshake
                        print "         Transfer: ↓" rx " ↑" tx
                    } else {
                        print "     Status: disconnected (no handshake)"
                    }
                }
            ')
        else
            stats="     Status: not loaded"
        fi

        echo "- $client"
        echo "  IP: $ip"
        echo "  Pubkey: ${pubkey:0:16}..."
        echo "$stats"
    done

    exit 0
fi

# ADD CLIENT
if [[ "$ACTION" != "add" ]]; then
    echo "[x] Invalid action: '$ACTION'. Use 'add' or 'remove'"
    usage
fi

if [[ -z "$CLIENT_NAME" ]]; then
    echo "[x] Client name is required when adding a peer."
    usage
fi

# Prevent reserved or dangerous names
if [[ "$CLIENT_NAME" =~ ^(server|add|remove|list|help)$ ]]; then
    echo "[!] Invalid or reserved client name: '$CLIENT_NAME'"
    exit 1
fi

function get_next_ip() {
    local base="10.66.66"
    local used_ips=$(grep -oP "${base}\.\d+" "$PEER_DIR"/*.conf || true)

    for i in $(seq 2 254); do
        ip="${base}.${i}"
        if ! echo "$used_ips" | grep -q "$ip"; then
            echo "$ip"
            return
        fi
    done

    echo "Error: No free IPs available in subnet!" >&2
    exit 1
}

CLIENT_IP="${3:-$(get_next_ip)}"

mkdir -p "$KEY_DIR" "$CONF_DIR" "$PEER_DIR"
umask 077

wg genkey | tee "$KEY_DIR/${CLIENT_NAME}_private.key" | wg pubkey > "$KEY_DIR/${CLIENT_NAME}_public.key"

CLIENT_PRIV=$(cat "$KEY_DIR/${CLIENT_NAME}_private.key")
CLIENT_PUB=$(cat "$KEY_DIR/${CLIENT_NAME}_public.key")

chmod 600 "$KEY_DIR/${CLIENT_NAME}_private.key"
chmod 644 "$KEY_DIR/${CLIENT_NAME}_public.key"

SERVER_PUB=$(cat "$KEY_DIR/server_public.key")

# Create client config
cat > "$CONF_DIR/${CLIENT_NAME}.conf" <<EOF
[Interface]
PrivateKey = $CLIENT_PRIV
Address = ${CLIENT_IP}/32

[Peer]
PublicKey = $SERVER_PUB
Endpoint = $SERVER_ENDPOINT
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF

# Create peer definition
cat > "$PEER_DIR/${CLIENT_NAME}.conf" <<EOF
# ${CLIENT_NAME}
[Peer]
PublicKey = $CLIENT_PUB
AllowedIPs = ${CLIENT_IP}/32
EOF

# Rebuild & Reload
rebuild_wg0
echo "[+] Added: $CLIENT_NAME"
echo "    -> Config: $CONF_DIR/${CLIENT_NAME}.conf"
echo "    -> IP: $CLIENT_IP"

# Optional QR code for phones
if command -v qrencode &>/dev/null; then
    read -p "Print QR code? (y/N) " printQR
    printQR=${printQR,,}
    if [[ "$printQR" =~ ^y(es)?$ ]]; then
        echo "[*] QR Code:"
        qrencode -t ansiutf8 < "$CONF_DIR/${CLIENT_NAME}.conf"
    fi
fi