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

SSH_DIR="$HOME/.ssh"
[[ ! -d "$SSH_DIR" ]] && _err "No ~/.ssh directory found."

echo "[*] Fixing permissions in $SSH_DIR ..."

# ~/.ssh directory should be 700
chmod 700 "$SSH_DIR"

# Private keys: 600
find "$SSH_DIR" -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \;

# Public keys: 644
find "$SSH_DIR" -type f -name '*.pub' -exec chmod 644 {} \;

# Authorized keys: 600
if [[ -f "$SSH_DIR/authorized_keys" ]]; then
    chmod 600 "$SSH_DIR/authorized_keys"
fi

# Known hosts & config files: 644
for f in config known_hosts known_hosts.old; do
    if [[ -f "$SSH_DIR/$f" ]]; then
        chmod 644 "$SSH_DIR/$f"
    fi
done

_notif "Permissions fixed." o
