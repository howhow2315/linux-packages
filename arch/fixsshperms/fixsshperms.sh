#!/bin/bash
# A quick fix script for .ssh permissions
source /usr/lib/howhow/common.sh
_require_root "$@"

# Locate SSH directory
if [[ "$(basename "$PWD")" == ".ssh" ]]; then
    SSH_DIR="$PWD"
else
    # Try to detect current user's .ssh (preferring sudo caller if any)
    USERNAME=${SUDO_USER:-$USER}
    USER_HOME=$(eval echo "~$USERNAME")
    SSH_DIR="$USER_HOME/.ssh"
fi

[[ -d "$SSH_DIR" ]] || _err "No .ssh directory found at $SSH_DIR"

_notif "Fixing permissions in $SSH_DIR ..."

# ~/.ssh directory should be 700
_notif "~/.ssh directory should be 700"
chmod 700 "$SSH_DIR"

# Private keys: 600
_notif "Private keys should be 600"
find "$SSH_DIR" -type f -name 'id_*' ! -name '*.pub' -exec chmod 600 {} \;

# Public keys: 644
_notif "Public keys should be 644"
find "$SSH_DIR" -type f -name '*.pub' -exec chmod 644 {} \;

# Authorized keys: 600
if [[ -f "$SSH_DIR/authorized_keys" ]]; then
    _notif "Authorized keys should be 600"
    chmod 600 "$SSH_DIR/authorized_keys"
fi

# Known hosts & config files: 644
for f in config known_hosts known_hosts.old; do
    _notif "Known hosts & config files keys should be 644"
    [[ -f "$SSH_DIR/$f" ]] && chmod 644 "$SSH_DIR/$f"
done

_notif "Permissions fixed." o
