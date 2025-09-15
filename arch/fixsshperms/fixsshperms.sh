#!/bin/bash
set -euo pipefail

SSH_DIR="$HOME/.ssh"

if [[ ! -d "$SSH_DIR" ]]; then
    echo "No ~/.ssh directory found."
    exit 1
fi

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

echo "[o] Permissions fixed."
