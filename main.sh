#!/bin/bash
# ========================================
# Live 24/7 YouTube usando FFmpeg + Railway
# ========================================

# === CONFIGURAÇÕES ===
STREAMKEY=${STREAMKEY:-"COLOQUE_SUA_STREAMKEY_AQUI"}
VIDEO="video.mp4"
PLAYLIST_DIR="musicas"
TEMP_PLAYLIST="playlist.txt"

# === GERA A LISTA DE MÚSICAS ===
rm -f "$TEMP_PLAYLIST"
for f in $PLAYLIST_DIR/*.mp3; do
  echo "file '$f'" >> "$TEMP_PLAYLIST"
done

# === LOOP INFINITO DA LIVE ===
while true; do
  ffmpeg -stream_loop -1 -i "$VIDEO" \
         -re -f concat -safe 0 -i "$TEMP_PLAYLIST" \
         -shortest \
         -c:v libx264 -preset veryfast -b:v 1500k -maxrate 1500k -bufsize 3000k -pix_fmt yuv420p \
         -c:a aac -b:a 128k -ar 44100 \
         -f flv "rtmps://a.rtmp.youtube.com:443/live2/$STREAMKEY"

  echo "FFmpeg caiu — reiniciando em 10s..."
  sleep 10
done
