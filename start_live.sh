#!/bin/bash
# Concatena todas as músicas mp3 da pasta musicas_fixed em um arquivo temporário
TEMP_MP3="/app/playlist_temp.mp3"
rm -f $TEMP_MP3
for f in /app/musicas_fixed/*.mp3; do
    echo "file '$f'" >> /app/concat_list.txt
done

ffmpeg -f concat -safe 0 -i /app/concat_list.txt -c copy $TEMP_MP3

# Mantém a live rodando
while true; do
  ffmpeg -re -stream_loop -1 -i $TEMP_MP3 -i /app/video.mp4 \
    -map 1:v:0 -map 0:a:0 \
    -vf "scale=1920:1080" \
    -c:v libx264 -preset veryfast -b:v 6000k -maxrate 6000k -bufsize 12000k \
    -c:a aac -b:a 128k -f flv rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY

  echo "FFmpeg travou ou finalizou, reiniciando em 5s..."
  sleep 5
done
