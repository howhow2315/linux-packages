#!/bin/bash
source /usr/lib/howhow/common.sh
_require_root "$@"

USAGE_ARGS+=("COMMAND" "[...]")
USAGE_MSG="

Commands:
    add <client-name> [client-ip]
    remove <client-name>
    list
"

# Defaults
ACTION="${1:-}"
CLIENT_NAME="${2:-}"

KEY_DIR="/etc/wireguard/keys"
CONF_DIR="/etc/wireguard/clients"
PEER_DIR="/etc/wireguard/peers"
WG_BASE="/etc/wireguard/wg0.base.conf"
WG_CONF="/etc/wireguard/wg0.conf"

WG_PORT="51820"

SERVER_PUBLIC_IP="129.80.84.37"
SERVER_ENDPOINT="${SERVER_PUBLIC_IP}:${WG_PORT}"
WG_INTERFACE="wg0"

function rebuild_wg0() {
    _notif "Rebuilding wg0.conf..."
    [[ ! -s "$WG_BASE" ]] && _err "Base config ($WG_BASE) is missing or empty. Aborting."

    cat "$WG_BASE" > "$WG_CONF"
    for peer in "$PEER_DIR"/*.conf; do
        [[ -s "$peer" ]] && { echo >> "$WG_CONF"; cat "$peer" >> "$WG_CONF"; }
    done

    # Clear out all stale peers:
    _notif "Refreshing peers..." *
    sudo wg-quick down wg0 && sudo wg-quick up wg0

    # Reload WireGuard
    wg addconf "$WG_INTERFACE" <(wg-quick strip "$WG_INTERFACE")

    _notif "wg0.conf has been rebuilt." o
}

# REMOVE CLIENT
if [[ "$ACTION" == "remove" ]]; then
    [[ -z "$CLIENT_NAME" ]] && _usage

    _notif "Removing client: $CLIENT_NAME" -

    # Remove peer block from wg0.conf
    sudo sed -i "/# ${CLIENT_NAME}/,+2d" "$WG_CONF"

    # Remove keys and config
    rm -f "$KEY_DIR/${CLIENT_NAME}_private.key"
    rm -f "$KEY_DIR/${CLIENT_NAME}_public.key"
    rm -f "$CONF_DIR/${CLIENT_NAME}.conf"
    rm -f "$PEER_DIR/${CLIENT_NAME}.conf"

    # Rebuild & Reload
    rebuild_wg0
    _notif "Client '$CLIENT_NAME' removed" o
    exit 0
fi

# LIST CLIENTS
if [[ "$ACTION" == "list" ]]; then
    _notif "Existing clients:"
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
                        print "Status: connected"
                        print "         Endpoint: " endpoint
                        print "         Last handshake: " handshake
                        print "         Transfer: ↓" rx " ↑" tx
                    } else {
                        print "Status: disconnected (no handshake)"
                    }
                }
            ')
        else
            stats="Status: not loaded"
        fi

        echo "- $client
    IP: $ip
    Pubkey: ${pubkey:0:16}...
    $stats
"
    done

    exit 0
fi

# ADD CLIENT
[[ "$ACTION" != "add" ]] && _notif "Invalid action: '$ACTION'. Use 'add' or 'remove'" x && _usage
[[ -z "$CLIENT_NAME" ]] && _notif "Client name is required when adding a peer." x && _usage
[[ "$CLIENT_NAME" =~ ^(server|add|remove|list|help)$ ]] &&  _err "Invalid or reserved client name: '$CLIENT_NAME'" # Prevent reserved or dangerous names

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

    _err "No free IPs available in subnet!"
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
_notif "Added: $CLIENT_NAME
    -> Config: $CONF_DIR/${CLIENT_NAME}.conf
    -> IP: $CLIENT_IP
" +

# (Optional) QR code handling
if _hascmd qrencode; then
    read -p "Print QR code? (y/N) " printQR
    printQR=${printQR,,}
    if [[ "$printQR" =~ ^y(es)?$ ]]; then
        _notif "QR Code:"
        qrencode -t ansiutf8 < "$CONF_DIR/${CLIENT_NAME}.conf"
    fi
fi