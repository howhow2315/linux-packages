#!/bin/bash
# A yt-dlp wrapper that downloads videos as MP4 or extracts audio as MP3 with metadata, thumbnails, and playlist support.
source /usr/lib/howhow/common.sh

USAGE_ARGS+=("FORMAT <URL>")
USAGE_CMDS+=("yt-dlp --help")

[[ $# -eq 0 ]] && _usage

PATH_FMT="%(album,playlist,track,title)s"
cmd=(
    "-U" 
    "--embed-metadata"
    "--no-overwrites"
    "--write-thumbnail"
    "--convert-thumbnails" "jpg"
    "-o" "$PATH_FMT/%(playlist_index,artist,composer,uploader)s - %(title)s.%(ext)s"
    "-o" "thumbnail:$PATH_FMT/cover.%(ext)s"
    '-o' "pl_thumbnail:"
)
_hascmd firefox && cmd+=("--cookies-from-browser" "firefox")
has_format=false
for arg in "$@"; do
    case "$arg" in
        -t|--audio-format|-f|--format)
            has_format=true
            break
            ;;
        -h|--help) _usage ;;
    esac
done
! $has_format && cmd+=("-t" "aac") # Add default if no format/preset was provided
cmd+=("$@")
yt-dlp "${cmd[@]}" # Run in current shell