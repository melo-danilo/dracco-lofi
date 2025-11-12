#!/bin/bash
# ========================================
# Live 24/7 YouTube: vídeo mudo + MP3s tocando uma por vez,
# detectando novas faixas e convertendo automaticamente
# ========================================

set -euo pipefail

STREAMKEY=${STREAMKEY:-"COLOQUE_SUA_STREAMKEY_AQUI"}
VIDEO="video.mp4"
SOURCE_DIR="musicas"
FIXED_DIR="musicas_fixed"
LOGFILE="stream.log"

mkdir -p "$FIXED_DIR"

echo "Iniciando live dinâmica com correção automática - $(date)" | tee -a "$LOGFILE"

# Função para converter novas músicas
convert_new_tracks() {
    for f in "$SOURCE_DIR"/*.mp3; do
        [ -e "$f" ] || continue
        base=$(basename "$f")
        target="$FIXED_DIR/$base"
        if [ ! -f "$target" ]; then
            echo "Convertendo $f para $target ..." | tee -a "$LOGFILE"
            ffmpeg -y -i "$f" -map 0:a -c:a libmp3lame -b:a 128k "$target" >>"$LOGFILE" 2>&1 || \
            echo "Falha ao converter $f, pulando..." | tee -a "$LOGFILE"
        fi
    done
}

# Loop infinito para live
while true; do
    # Converte automaticamente novos arquivos
    convert_new_tracks

    # Lista todas as MP3s prontas
    MP3_LIST=("$FIXED_DIR"/*.mp3)

    # Se não houver MP3s, aguarda 10 segundos e tenta de novo
    if [ ! -e "${MP3_LIST[0]}" ]; then
        echo "Nenhuma MP3 encontrada em $FIXED_DIR. Aguardando 10s..." | tee -a "$LOGFILE"
        sleep 10
        continue
    fi

    # Loop por cada faixa
    for MP3 in "${MP3_LIST[@]}"; do
        echo "Transmitindo faixa: $MP3 - $(date)" | tee -a "$LOGFILE"

        # Roda FFmpeg: vídeo mudo + faixa atual
        ffmpeg -re -stream_loop -1 -i "$VIDEO" \
               -i "$MP3" \
               -map 0:v -map 1:a \
               -c:v libx264 -preset veryfast -b:v 1500k -maxrate 1500k -bufsize 3000k -r 30 -pix_fmt yuv420p \
               -c:a aac -b:a 128k -ar 44100 \
               -f flv "rtmps://a.rtmp.youtube.com:443/live2/$STREAMKEY" \
               >>"$LOGFILE" 2>&1 || echo "FFmpeg caiu, passando para próxima faixa..." | tee -a "$LOGFILE"

        sleep 2
    done

    echo "Verificando novamente $SOURCE_DIR para novas faixas..." | tee -a "$LOGFILE"
done
