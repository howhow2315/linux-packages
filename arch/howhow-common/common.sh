set -euo pipefail

CMD=$(basename "$0")

# Display a message "[*] with a symbol prefix"
_notif() {
    local msg="${1:-""}" sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}

# Print a blank line, then display a message "[*] with a symbol prefix"
_notif_sep() { 
    echo
    _notif "$@"
}

# Clear the terminal, then display a message "[*] with a symbol prefix"
_notif_clear() { 
    clear
    _notif "$@"
}

_bell() { (echo -e '\a') }

USAGE_ARGS=()
USAGE_MSG=""
USAGE_CMDS=()

# Print usage message and call any registered usage commands, then exit [ USAGE_ARGS=(), USAGE_MSG="", USAGE_CMDS=() ]
_usage() {
    echo "Usage: $CMD ${USAGE_ARGS[@]}... $USAGE_MSG"
    for cmd in "${USAGE_CMDS[@]}"; do
        $cmd
    done
    exit 1
}

# Display an error message and exit with a specified code (default 1)
_err() {
    local msg="$1" code=${2:-1}
    _notif "$CMD ERROR: $msg" !
    exit "$code"
}

# Run a command silently, suppressing stdout and stderr, shell-dependent
case "$(basename "$SHELL")" in
    bash|zsh) _silently() { "$@" &> /dev/null; } ;;
    *) _silently() { "$@" > /dev/null 2>&1; } ;; # Default to POSIX-compatible syntax
esac

# Check if a command exists in PATH
_hascmd() { _silently command -v "$1"; }

# Check if a specific flag exists in a list of arguments
_contains_arg() {
    local pattern="$1"
    shift # remove the first argument, leaving the array
    local args=("$@")

    for item in "${args[@]}"; do
        [[ "$item" =~ "$pattern" ]] && return 0
    done
    return 1
}

# Return true if the current user is root
_is_root() { (( EUID == 0 )) }

# Return true only if both stdin (0) and stdout (1) are terminals.
_is_terminal() { [[ -t 0 && -t 1 ]] }

# Returns the original user who invoked the script, falling back to $USER or logname
_get_user() { (echo "${SUDO_USER:-${USER:-$(logname)}}") }

# Ensure the script runs as root, re-executing under sudo if available
_require_root() {
    if ! _is_root; then
        if _hascmd sudo; then
            _notif "Action requires root privileges, running under sudo: '$CMD${*:+ $*}'"
            exec sudo "$0" "$@"
        else
            _err "You need to be root to run this script"
        fi
    fi
}

# Drop root privileges and re-run the script as the original user
_drop_privileges() {
    if _is_root; then
        _notif "Dropping root privileges, switching to user: '${SUDO_USER:-$(logname)}'"
        if _hascmd sudo && [[ -n "${SUDO_USER:-}" ]]; then
            exec sudo -u "$SUDO_USER" "$0" "$@"
        else
            _err "Cannot safely drop privileges; rerun as a regular user"
        fi
    fi
}

# Run a command as root, using sudo if necessary
_run_as_root() {
    if ! _is_root; then
        if _hascmd sudo; then
            _notif "Internal action requires root privileges, running under sudo: '$*'"
            sudo "$@"
        else
            _err "You need to be root to run this script"
        fi
    else
        "$@"
    fi
    return 0
}