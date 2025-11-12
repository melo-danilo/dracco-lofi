#!/bin/bash
# ========================================
# Live 24/7 YouTube usando FFmpeg + Railway
# (video mudo + playlist de MP3s em loop)
# ========================================

set -euo pipefail

# === CONFIGURAÇÕES ===
STREAMKEY=${STREAMKEY:-"COLOQUE_SUA_STREAMKEY_AQUI"}
VIDEO="video.mp4"
PLAYLIST_DIR="musicas"
TEMP_PLAYLIST="playlist.txt"
CONCAT_AUDIO="concatenated.mp3"
LOGFILE="stream.log"

# === FUNÇÃO: gera playlist.txt para concat demuxer ===
generate_playlist() {
  rm -f "$TEMP_PLAYLIST"
  for f in "$PLAYLIST_DIR"/*.mp3; do
    # pula se não houver mp3s
    [ -f "$f" ] || continue
    # concat demuxer precisa de paths com aspas simples
    echo "file '$PWD/$f'" >> "$TEMP_PLAYLIST"
  done
}

# === GERA O ARQUIVO DE ÁUDIO CONCATENADO ===
# (usa copy para ser rápido; se as mp3 tiverem headers incompatíveis, converte para mp3 padrão)
build_concatenated_audio() {
  if [ ! -s "$TEMP_PLAYLIST" ]; then
    echo "Nenhum MP3 encontrado em $PLAYLIST_DIR. Saindo..." | tee -a "$LOGFILE"
    exit 1
  fi

  # Remove arquivo antigo
  rm -f "$CONCAT_AUDIO"

  # Tenta concatenar com copy (rápido). Se falhar, converte recodificando.
  echo "Gerando $CONCAT_AUDIO a partir das faixas..." | tee -a "$LOGFILE"
  if ffmpeg -f concat -safe 0 -i "$TEMP_PLAYLIST" -c copy "$CONCAT_AUDIO" -y >>"$LOGFILE" 2>&1; then
    echo "Concatenado (copy) criado: $CONCAT_AUDIO" | tee -a "$LOGFILE"
  else
    echo "Concatenado (copy) falhou — recodificando para MP3 padrão..." | tee -a "$LOGFILE"
    ffmpeg -f concat -safe 0 -i "$TEMP_PLAYLIST" -c:a libmp3lame -q:a 4 "$CONCAT_AUDIO" -y >>"$LOGFILE" 2>&1
    echo "Concatenado (recodificado) criado: $CONCAT_AUDIO" | tee -a "$LOGFILE"
  fi
}

# === GERA PLAYLIST E CONCANTENAÇÃO ===
generate_playlist
build_concatenated_audio

# === LOOP INFINITO com reconexão automática ===
while true; do
  echo "Iniciando FFmpeg stream (video mudo + audio $CONCAT_AUDIO) - $(date)" | tee -a "$LOGFILE"

  # -map 0:v -> pega apenas o vídeo do video.mp4 (ignora audio interna)
  # -map 1:a -> pega áudio do concatenated.mp3
  # usamos -stream_loop -1 em ambos inputs para loop contínuo
  ffmpeg -re -stream_loop -1 -i "$VIDEO" \
         -re -stream_loop -1 -i "$CONCAT_AUDIO" \
         -map 0:v -map 1:a \
         -c:v libx264 -preset veryfast -b:v 1500k -maxrate 1500k -bufsize 3000k -r 30 -pix_fmt yuv420p \
         -c:a aac -b:a 128k -ar 44100 \
         -f flv "rtmps://a.rtmp.youtube.com:443/live2/$STREAMKEY" \
         >>"$LOGFILE" 2>&1

  echo "FFmpeg saiu/colidiu — reiniciando em 10s..." | tee -a "$LOGFILE"
  sleep 10

  # Se você atualizar as MP3s no diretório, regenere o concatenado automaticamente:
  # (opcional) detecta mudanças simples e reconstrói
  generate_playlist
  build_concatenated_audio
done
