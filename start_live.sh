#!/bin/bash
# Loop contínuo das músicas, otimizado para CPU baixa

MUSIC_DIR="musicas_fixed"

while true; do
  for MUSIC in "$MUSIC_DIR"/*.mp3; do
    echo "Tocando: $MUSIC"

    ffmpeg -re -i video.mp4 -i "$MUSIC" \
      -map 0:v:0 -map 1:a:0 \
      -vf "scale=1920:1080" \
      -c:v libx264 -preset veryfast -tune zerolatency -crf 23 \
      -r 30 \
      -c:a aac -b:a 128k -ar 44100 -ac 2 \
      - f flv rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY

    echo "Música finalizada, próximo..."
    sleep 2
  done
done
