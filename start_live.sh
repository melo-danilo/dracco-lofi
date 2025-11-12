#!/bin/bash
set -e

APP_DIR="/app"
MP3_DIR="$APP_DIR/mp3"
VIDEO_FILE="$APP_DIR/video.mp4"
TEMP_PLAYLIST="$APP_DIR/playlist_temp.mp3"
RTMP_URL="${STREAM_URL}"   # Coloque sua stream key como env var

# Função para gerar concat_list.txt
generate_concat_list() {
  echo "Gerando lista de concatenação..."
  ls "$MP3_DIR"/*.mp3 | sort | awk '{print "file \x27" $0 "\x27"}' > "$APP_DIR/concat_list.txt"
}

# Função para concatenar MP3s
concat_mp3s() {
  echo "Concatenando MP3s..."
  ffmpeg -f concat -safe 0 -i "$APP_DIR/concat_list.txt" -c copy "$TEMP_PLAYLIST"
}

# Função para iniciar live
start_live() {
  echo "Iniciando live..."
  ffmpeg -re -stream_loop -1 -i "$TEMP_PLAYLIST" \
         -stream_loop -1 -i "$VIDEO_FILE" \
         -c:v libx264 -b:v 6000k -pix_fmt yuv420p \
         -c:a aac -b:a 128k -ar 44100 -f flv "$RTMP_URL"
}

# Loop infinito para manter ffmpeg ativo
while true; do
  generate_concat_list
  concat_mp3s
  start_live
  echo "ffmpeg travou ou terminou inesperadamente. Reiniciando..."
  sleep 2
done
