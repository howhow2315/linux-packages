set -euo pipefail

CMD=$(basename "$0")

_notif() {
    local msg="${1:-""}" sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}
_notif_sep() { 
    echo
    _notif "$@"
}
_notif_clear() { 
    clear
    _notif "$@"
}

USAGE_ARGS=()
USAGE_MSG=""
USAGE_CMDS=()

_usage() {
    echo "Usage: $CMD ${USAGE_ARGS[@]}... $USAGE_MSG"
    for cmd in "${USAGE_CMDS[@]}"; do
        $cmd
    done
    exit 1
}

_err() {
    local msg="$1" code=${2:-1}
    _notif "$CMD ERROR: $msg" !
    exit "$code"
}

_hascmd() { command -v "$1" &>/dev/null; }

_is_root() { (( EUID == 0 )) }

_require_root() {
    if _is_root; then
        if _hascmd sudo; then
            _notif "This script is running as root via sudo: '$CMD $@'"
            exec sudo "$0" "$@"
        else
            _err "You need to be root to run this script"
        fi
    fi
}

_drop_privileges() {
    if (( EUID == 0 )); then
        _notif "Dropping root privileges, switching to user: '${SUDO_USER:-$(logname)}'"
        if _hascmd sudo && [[ -n "${SUDO_USER:-}" ]]; then
            exec sudo -u "$SUDO_USER" "$0" "$@"
        else
            _err "Cannot safely drop privileges; rerun as a regular user"
        fi
    fi
}

_run_as_root() {
    if _is_root; then
        if _hascmd sudo; then
            _notif "Running internal command as root via sudo: '$@'"
            sudo "$@"
        else
            _err "You need to be root to run this script"
        fi
    else
        "$@"
    fi
    return 0
}