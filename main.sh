#!/bin/bash
# ========================================
# Live 24/7 YouTube: vídeo mudo + MP3 playlist em loop
# ========================================

set -euo pipefail

STREAMKEY=${STREAMKEY:-"COLOQUE_SUA_STREAMKEY_AQUI"}
VIDEO="video.mp4"
PLAYLIST_DIR="musicas"
LOGFILE="stream.log"

# === GERA LISTA DE INPUTS PARA CONCAT DYNAMICO ===
INPUTS=()
FILTERS=()
INDEX=0

for f in "$PLAYLIST_DIR"/*.mp3; do
    [ -f "$f" ] || continue
    INPUTS+=("-i" "$f")
    FILTERS+=("[$INDEX:0]")
    INDEX=$((INDEX+1))
done

if [ ${#INPUTS[@]} -eq 0 ]; then
    echo "Nenhum MP3 encontrado em $PLAYLIST_DIR. Saindo..." | tee -a "$LOGFILE"
    exit 1
fi

# Cria filtro concat
FILTER_STR="${FILTERS[*]}concat=n=${#INPUTS[@]}:v=0:a=1[outa]"

echo "Iniciando live com ${#INPUTS[@]} faixas..." | tee -a "$LOGFILE"

# Loop infinito com reconexão
while true; do
    ffmpeg -re -stream_loop -1 -i "$VIDEO" "${INPUTS[@]}" \
           -filter_complex "$FILTER_STR" -map 0:v -map "[outa]" \
           -c:v libx264 -preset veryfast -b:v 1500k -maxrate 1500k -bufsize 3000k -r 30 -pix_fmt yuv420p \
           -c:a aac -b:a 128k -ar 44100 \
           -f flv "rtmps://a.rtmp.youtube.com:443/live2/$STREAMKEY" \
           >>"$LOGFILE" 2>&1 || echo "FFmpeg caiu, reiniciando em 10s..." | tee -a "$LOGFILE"

    sleep 10
done
