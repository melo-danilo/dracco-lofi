#!/bin/bash
set -e

# Caminho dos arquivos
MP3_DIR="/app/mp3"
VIDEO_FILE="/app/video.mp4"
TEMP_PLAYLIST="/app/playlist_temp.mp3"
CONCAT_LIST="/app/concat_list.txt"
STREAM_KEY="SEU_STREAM_KEY"
YOUTUBE_URL="rtmp://a.rtmp.youtube.com/live2/$STREAM_KEY"

echo "Gerando lista de concatenação..."
rm -f "$CONCAT_LIST"
for f in "$MP3_DIR"/*.mp3; do
    echo "file '$f'" >> "$CONCAT_LIST"
done

echo "Concatenando MP3s..."
ffmpeg -f concat -safe 0 -i "$CONCAT_LIST" -c copy "$TEMP_PLAYLIST"

echo "Iniciando live no YouTube..."
ffmpeg -re -stream_loop -1 -i "$VIDEO_FILE" -i "$TEMP_PLAYLIST" \
-c:v libx264 -preset veryfast -b:v 4500k -maxrate 4500k -bufsize 9000k -pix_fmt yuv420p \
-c:a aac -b:a 128k -ar 44100 -ac 2 \
-shortest -f flv "$YOUTUBE_URL"
