#!/bin/bash

set -euo pipefail
trap "echo 'Terminated'; exit 1" INT

usage() {
    local SH_CMD="$(basename "$0")"
    echo "Usage: $SH_CMD [-r|-l] HOST_NAME LOCAL_PORT [REMOTE_PORT] [LOCAL_IP] [REMOTE_IP]"
    echo
    echo "  -r|--reverse    Create a reverse SSH tunnel (server:REMOTE -> local:LOCAL) [DEFAULT]"
    echo "  -l|--local      Create a local SSH tunnel (local:LOCAL -> server:REMOTE)"
    echo "  -a|--autossh    Create the SSH connection using autossh."
    echo
    echo "  Example: $SH_CMD user@server.com 3000"
    echo "  ssh -v -N -R 0.0.0.0:3000:localhost:3000 user@server.com"
    exit 1
}

# Consider adding a "disable retry" flag for non-autossh connections

# Defaults
TUNNEL_MODE="reverse"
USE_AUTOSSH=false

# Argument Parsing
while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--reverse) TUNNEL_MODE="reverse" ;;
        -l|--local) TUNNEL_MODE="local" ;;
        -a|--autossh)
            if command -v autossh > /dev/null 2>&1; then
                echo "[!] autossh is enabled but not installed. Defaulting to basic SSH loop..."
            else
                USE_AUTOSSH=true
            fi
            ;;
        -h|--help) usage ;;
        -*) echo "Unknown flag: $1"; usage ;;
        *) break ;;
    esac
    shift
done

# Positional Arguments
HOST_NAME="${1:-}"
LOCAL_PORT="${2:-}"
REMOTE_PORT="${3:-"$LOCAL_PORT"}"
LOCAL_IP="${4:-localhost}"
REMOTE_IP="${5:-0.0.0.0}"
[[ -z "$HOST_NAME" || -z "$LOCAL_PORT" ]] && usage

print_info() {
    echo "Mode       : $TUNNEL_MODE tunnel"
    echo "Remote host: $HOST_NAME"
    echo "Local port : $LOCAL_PORT"
    echo "Remote port: $REMOTE_PORT"
    echo "Local ip   : $LOCAL_IP"
    echo "Remote ip  : $REMOTE_IP"
}

if [[ "$TUNNEL_MODE" == "reverse" ]]; then
    echo "[*] Creating reverse SSH tunnel..."
    ssh_cmd=(-N -R $REMOTE_IP:$REMOTE_PORT:$LOCAL_IP:$LOCAL_PORT "$HOST_NAME")
else
    echo "[*] Creating local SSH tunnel..."
    ssh_cmd=(-N -L $LOCAL_IP:$LOCAL_PORT:$REMOTE_IP:$REMOTE_PORT "$HOST_NAME")
fi

if $USE_AUTOSSH; then
    echo "[*] Attempting to tunnel with: autossh -M 0 ${ssh_cmd[*]}"
    autossh -M 0 "${ssh_cmd[@]}"
else
    # Network Check + Retry Loop
    while true; do
        if ping -c 1 1.1.1.1; then
            echo "[*] Attempting to tunnel with: ssh -v -o ExitOnForwardFailure=yes ${ssh_cmd[*]}"
            ssh -v -o ExitOnForwardFailure=yes "${ssh_cmd[@]}"
        else
            echo "[!] No network connection, retrying in 30s..."
            sleep 30
        fi
    done
fi