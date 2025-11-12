#!/bin/bash
# Mantém a live rodando mesmo se ffmpeg travar
while true; do
  ffmpeg -re -i video.mp4 -i musicas_fixed/Drift_Through_Time_1.mp3 \
    -map 0:v:0 -map 1:a:0 \
    -c:v libx264 -preset veryfast -b:v 4500k \
    -c:a aac -b:a 128k -f flv rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY
  echo "FFmpeg travou ou finalizou, reiniciando em 5s..."
  sleep 5
done
