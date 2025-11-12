#!/bin/bash
set -euo pipefail

APP_DIR="/app"
MP3_DIR="${MP3_DIR:-$APP_DIR/musicas}"
VIDEO_FILE="${VIDEO_FILE:-$APP_DIR/video.mp4}"
PLAYLIST_FILE="$APP_DIR/playlist_temp.mp3"
CONCAT_LIST="$APP_DIR/concat_list.txt"
RTMP_URL="${STREAM_URL:-}"

build_rtmp_url() {
  local stream_key="${YOUTUBE_STREAM_KEY:-${STREAM_KEY:-${STREAMKEY:-}}}"
  local base_url="${YOUTUBE_RTMP_BASE:-rtmp://a.rtmp.youtube.com/live2}"

  if [[ -n "$stream_key" ]]; then
    # remove sufixos "/" duplicados
    base_url="${base_url%/}"
    echo "${base_url}/${stream_key}"
    return 0
  fi

  return 1
}

start_healthcheck_server() {
  if [[ "${ENABLE_SERVER:-1}" != "1" ]]; then
    return
  fi

  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    return
  fi

  echo "Iniciando servidor Flask para health-check (porta 8080)..."
  python3 /app/server.py &
  SERVER_PID=$!
}

cleanup() {
  rm -f "$PLAYLIST_FILE" "$CONCAT_LIST"

  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    echo "Finalizando servidor Flask (PID $SERVER_PID)..."
    kill "$SERVER_PID"
  fi
}

trap cleanup EXIT

if [[ -z "$RTMP_URL" ]]; then
  if ! RTMP_URL="$(build_rtmp_url)"; then
    echo "Erro: defina a variável STREAM_URL com a URL completa RTMP ou YOUTUBE_STREAM_KEY/STREAM_KEY/STREAMKEY com a chave da live." >&2
    exit 1
  fi
fi

if [[ ! -d "$MP3_DIR" ]]; then
  echo "Erro: diretório de MP3 não encontrado em '$MP3_DIR'." >&2
  exit 1
fi

if [[ ! -f "$VIDEO_FILE" ]]; then
  echo "Erro: arquivo de vídeo não encontrado em '$VIDEO_FILE'." >&2
  exit 1
fi

shopt -s nullglob
MP3_FILES=("$MP3_DIR"/*.mp3)
shopt -u nullglob

if (( ${#MP3_FILES[@]} == 0 )); then
  echo "Erro: nenhum arquivo .mp3 encontrado em '$MP3_DIR'." >&2
  exit 1
fi

generate_concat_list() {
  echo "Gerando lista de concatenação com ${#MP3_FILES[@]} arquivos..."
  : > "$CONCAT_LIST"
  for file in "${MP3_FILES[@]}"; do
    printf "file '%s'\n" "$file" >> "$CONCAT_LIST"
  done
}

concat_mp3s() {
  echo "Concatenando MP3s em '$PLAYLIST_FILE'..."
  ffmpeg -hide_banner -loglevel warning \
         -f concat -safe 0 -i "$CONCAT_LIST" -c copy "$PLAYLIST_FILE"
}

start_live() {
  echo "Iniciando live para '$RTMP_URL'..."
  ffmpeg -hide_banner -re \
         -stream_loop -1 -i "$PLAYLIST_FILE" \
         -stream_loop -1 -i "$VIDEO_FILE" \
         -c:v libx264 -preset veryfast -tune stillimage \
         -b:v "${VIDEO_BITRATE:-4000k}" -maxrate "${VIDEO_MAXRATE:-4500k}" -bufsize "${VIDEO_BUFSIZE:-8000k}" \
         -pix_fmt yuv420p -g "${GOP_SIZE:-120}" \
         -c:a aac -b:a "${AUDIO_BITRATE:-128k}" -ar "${AUDIO_SAMPLE_RATE:-44100}" \
         -f flv "$RTMP_URL"
}

start_healthcheck_server

while true; do
  generate_concat_list
  concat_mp3s
  start_live
  echo "ffmpeg encerrou inesperadamente. Reiniciando em 2s..."
  sleep 2
done
