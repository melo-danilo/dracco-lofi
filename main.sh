#!/bin/bash
# ========================================
# Live 24/7 YouTube usando FFmpeg (video mudo + playlist MP3)
# ========================================

set -euo pipefail

# Configurações
STREAMKEY=${STREAMKEY:-"COLOQUE_SUA_STREAMKEY_AQUI"}
VIDEO="video.mp4"
PLAYLIST_DIR="musicas"
TEMP_PLAYLIST="playlist.txt"
CONCAT_AUDIO="concatenated.mp3"
LOGFILE="stream.log"

# === GERA PLAYLIST.TXT ===
rm -f "$TEMP_PLAYLIST"
for f in "$PLAYLIST_DIR"/*.mp3; do
  [ -f "$f" ] || continue
  echo "file '$PWD/$f'" >> "$TEMP_PLAYLIST"
done

# === GERA ARQUIVO CONCATENADO (uma vez) ===
rm -f "$CONCAT_AUDIO"
ffmpeg -f concat -safe 0 -i "$TEMP_PLAYLIST" -c copy "$CONCAT_AUDIO" -y >>"$LOGFILE" 2>&1 || \
ffmpeg -f concat -safe 0 -i "$TEMP_PLAYLIST" -c:a libmp3lame -q:a 4 "$CONCAT_AUDIO" -y >>"$LOGFILE" 2>&1

echo "Arquivo concatenado criado: $CONCAT_AUDIO" | tee -a "$LOGFILE"

# === RODA O STREAM FFmpeg EM LOOP INFINITO (reconexão automática) ===
while true; do
  echo "Iniciando FFmpeg stream (video mudo + audio $CONCAT_AUDIO) - $(date)" | tee -a "$LOGFILE"

  ffmpeg -re -stream_loop -1 -i "$VIDEO" \
         -re -stream_loop -1 -i "$CONCAT_AUDIO" \
         -map 0:v -map 1:a \
         -c:v libx264 -preset veryfast -b:v 1500k -maxrate 1500k -bufsize 3000k -r 30 -pix_fmt yuv420p \
         -c:a aac -b:a 128k -ar 44100 \
         -f flv "rtmps://a.rtmp.youtube.com:443/live2/$STREAMKEY" \
         >>"$LOGFILE" 2>&1

  echo "FFmpeg caiu, reiniciando em 10s..." | tee -a "$LOGFILE"
  sleep 10
done
