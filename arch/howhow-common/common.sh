#!/bin/bash
set -euo pipefail

CMD=$(basename "$0")

_notif() {
    local msg="$1" sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}

_err() {
    local msg="$1" code=${2:-1}
    _notif "$CMD ERROR: $msg" !
    exit "$code"
}

_hascmd() { command -v "$1" &>/dev/null; }

_elevate() {
    if (( EUID != 0 )); then
        if _hascmd sudo; then
            _notif "This script is running as root via sudo: '$CMD $@'"
            exec sudo "$0" "$@"
        else
            _err "You need to be root to run this script"
        fi
    fi
}