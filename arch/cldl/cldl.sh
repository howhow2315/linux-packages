#!/bin/bash
# A yt-dlp wrapper that downloads videos as MP4 or extracts audio as MP3 with metadata, thumbnails, and playlist support.
set -euo pipefail
_notif() {
    local msg="$1" sym=${2:-"*"}
    [[ -n "$msg" ]] && echo "[$sym] $msg"
}
CMD=$(basename "$0")
_usage() { echo "Usage: $CMD [--audio|--video] <URL>"; exit 1; }

# Defaults
flags=()
arguments=()
verbose=false
mode="audio"

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help) _usage ;;
        -v|--verbose) verbose=true ;;
        --video) mode="video" ;;
        --audio) mode="audio" ;;
        -*) flags+=("$1 $2"); shift ;;
        *) arguments+=("$1") ;;
    esac
    shift
done

$verbose && arguments+=("--verbose")
URL="${arguments[0]}"

if grep -q "playlist" <<< "$URL"; then
    outtmpl="%(playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
else
    outtmpl="%(title)s.%(ext)s"
fi

# Build yt-dlp command
if [[ "$mode" == "audio" ]]; then
    cmd=(yt-dlp -U -f "bestaudio/best" -x --audio-format mp3 --cookies-from-browser firefox --embed-metadata --no-overwrites --embed-thumbnail -o "$outtmpl" "$URL")
else
    cmd=(yt-dlp -U -f "bestvideo+bestaudio/best" --merge-output-format mp4 --cookies-from-browser firefox --embed-metadata --no-overwrites -o "$outtmpl" "$URL")
fi

$verbose && _notif "Executing: '${cmd[*]}'" "+"
exec "${cmd[@]}"
