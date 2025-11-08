#!/bin/bash
# A yt-dlp wrapper that downloads videos as MP4 or extracts audio as MP3 with metadata, thumbnails, and playlist support.
source /usr/lib/howhow/common.sh

USAGE_ARGS+=("[--audio|--video]" "<URL>")

[[ $# -eq 0 ]] && _usage

# Defaults
flags=()
arguments=()
verbose=false
mode="audio"
cmd=("yt-dlp" "-U" "--embed-metadata" "--no-overwrites" "--cookies-from-browser" "firefox")

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
    outtmpl="%(album,playlist)s/%(playlist_index)s - %(title)s.%(ext)s"
else
    outtmpl="%(title)s.%(ext)s"
fi

# Build yt-dlp command
if [[ "$mode" == "audio" ]]; then
    cmd+=("-f" "bestaudio/best" "-x" "--audio-format" "mp3" "--embed-thumbnail" "-o" "$outtmpl" "$URL")
else
    cmd+=("-f" "bestvideo+bestaudio/best" "--merge-output-format" "mp4" "-o" "$outtmpl" "$URL")
fi

$verbose && _notif "Executing: '${cmd[*]}'" "+"
exec "${cmd[@]}"
