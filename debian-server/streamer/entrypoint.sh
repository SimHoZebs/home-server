#!/bin/bash
set -euo pipefail

if [ -z "${TWITCH_KEY:-}" ] || [ -z "${YOUTUBE_KEY:-}" ]; then
  echo "Error: TWITCH_KEY and YOUTUBE_KEY environment variables must be set." >&2
  exit 1
fi

echo "Starting Streamer with env-based keys to avoid command-line exposure..."

exec ffmpeg \
  -i "srt://0.0.0.0:9998?mode=listener&latency=3000" \
  -fflags +genpts+discardcorrupt \
  -map 0:v -map 0:a -c:v h264_nvenc -preset:v p6 -b:v 6000k -bufsize:v 12000k -g 120 -keyint_min 120 -c:a copy -f flv "rtmp://ingest.global-contribute.live-video.net/app/${TWITCH_KEY}" \
  -map 0:v -map 0:a -c:v copy -c:a copy -f flv "rtmp://a.rtmp.youtube.com/live2/${YOUTUBE_KEY}"
