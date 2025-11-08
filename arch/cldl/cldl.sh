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
cmd=("yt-dlp" "-U" "--embed-metadata" "--no-overwrites")
_hascmd firefox && cmd+=("--cookies-from-browser" "firefox")

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

cmd+=(-o "%(album,playlist,track,title)s/%(playlist_index,artist,composer,uploader)s - %(title)s.%(ext)s")
if [[ "$mode" == "audio" ]]; then
    cmd+=("-f" "bestaudio/best" "-x" "--audio-format" "mp3" "--embed-thumbnail" "$URL")
else
    cmd+=("-f" "bestvideo+bestaudio/best" "--merge-output-format" "mp4" "$URL")
fi

$verbose && _notif "Executing: '${cmd[*]}'" "+"
exec "${cmd[@]}"
