#!/bin/bash
# ========================================
# Live 24/7 YouTube: vídeo mudo + MP3s tocando uma por vez, detectando novas faixas
# ========================================

set -euo pipefail

STREAMKEY=${STREAMKEY:-"COLOQUE_SUA_STREAMKEY_AQUI"}
VIDEO="video.mp4"
PLAYLIST_DIR="musicas"
LOGFILE="stream.log"

echo "Iniciando live dinâmica - $(date)" | tee -a "$LOGFILE"

# Loop infinito para manter a live rodando
while true; do
    # Lista todas as MP3s atuais
    MP3_LIST=("$PLAYLIST_DIR"/*.mp3)
    # Ignora se não houver MP3s
    if [ ! -e "${MP3_LIST[0]}" ]; then
        echo "Nenhuma MP3 encontrada em $PLAYLIST_DIR. Aguardando 10s..." | tee -a "$LOGFILE"
        sleep 10
        continue
    fi

    # Loop por cada faixa disponível
    for MP3 in "${MP3_LIST[@]}"; do
        echo "Transmitindo faixa: $MP3 - $(date)" | tee -a "$LOGFILE"

        # Roda FFmpeg: video mudo + faixa atual
        ffmpeg -re -stream_loop -1 -i "$VIDEO" \
               -i "$MP3" \
               -map 0:v -map 1:a \
               -c:v libx264 -preset veryfast -b:v 1500k -maxrate 1500k -bufsize 3000k -r 30 -pix_fmt yuv420p \
               -c:a aac -b:a 128k -ar 44100 \
               -f flv "rtmps://a.rtmp.youtube.com:443/live2/$STREAMKEY" \
               >>"$LOGFILE" 2>&1 || echo "FFmpeg caiu, passando para próxima faixa..." | tee -a "$LOGFILE"

        # Pequeno delay antes de tocar a próxima faixa
        sleep 2
    done

    # Depois de tocar todas as faixas, volta e lê novamente o diretório
    echo "Verificando novamente o diretório $PLAYLIST_DIR para novas faixas..." | tee -a "$LOGFILE"
done
