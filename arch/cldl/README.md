# cldl

A `yt-dlp` wrapper for downloading videos and audio with metadata, thumbnails, and playlist support.

## Features

- Downloads audio/video with embedded metadata
- Writes and converts thumbnails
- Supports playlists with organized output folders
- Default audio format set to AAC if none specified
- Integrates cookies from Firefox for authenticated downloads
- Avoids overwriting existing files

## Usage

```sh
cldl [yt-dlp options] URL
```

Currently only supports 4 presets  
   
Audio:  
mp3, aac  
  
Video:  
mp4, mkv  
  
Defaults to aac. To change presets, use the `-t <preset>` flag