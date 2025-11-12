#!/bin/bash
# start_live.sh

VIDEO="video.mp4"
MUSIC_DIR="musicas_fixed"
STREAM_URL="rtmp://a.rtmp.youtube.com/live2/$STREAMKEY"

while true; do
  for MUSIC in "$MUSIC_DIR"/*.mp3; do
    echo "Tocando: $MUSIC"

    ffmpeg -re -stream_loop -1 -i "$VIDEO" -i "$MUSIC" \
      -map 0:v:0 -map 1:a:0 \
      -vf "scale=1920:1080" \
      -c:v libx264 -preset veryfast -b:v 6000k -maxrate 6000k -bufsize 12000k \
      -c:a aac -b:a 128k -f flv "$STREAM_URL"

    echo "FFmpeg travou ou música finalizou, próximo..."
    sleep 5
  done
done
