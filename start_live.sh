#!/bin/bash
set -euo pipefail

APP_DIR="/app"
CHANNEL_NAME="${CHANNEL_NAME:-}"
CHANNEL_CONFIG_FILE="${CHANNEL_CONFIG_FILE:-}"
PREVIEW="${PREVIEW:-0}"   # se 1 => modo preview (não envia para RTMP)

if [[ -n "$CHANNEL_NAME" ]]; then
  CHANNEL_CONFIG_FILE="${CHANNEL_CONFIG_FILE:-$APP_DIR/config/${CHANNEL_NAME}.env}"
fi

if [[ -n "$CHANNEL_CONFIG_FILE" && -f "$CHANNEL_CONFIG_FILE" ]]; then
  echo "Carregando configuração do canal '${CHANNEL_NAME:-default}' em '$CHANNEL_CONFIG_FILE'..."
  set -a
  source "$CHANNEL_CONFIG_FILE"
  set +a
else
  echo "Erro: arquivo de configuração '$CHANNEL_CONFIG_FILE' não encontrado." >&2
  exit 1
fi

MP3_DIR="${MP3_DIR:-$APP_DIR/musicas}"
VIDEO_FILE="${VIDEO_FILE:-$APP_DIR/video/${CHANNEL_NAME:-default}.mp4}"
PLAYLIST_FILE="$APP_DIR/playlist_temp.mp3"
CONCAT_LIST="$APP_DIR/concat_list.txt"

VIDEO_SCALE="${VIDEO_SCALE:-1920:1080}"
VIDEO_FPS="${VIDEO_FPS:-30}"
VIDEO_PRESET="${VIDEO_PRESET:-superfast}"
VIDEO_BITRATE="${VIDEO_BITRATE:-4500k}"
VIDEO_MAXRATE="${VIDEO_MAXRATE:-5500k}"
VIDEO_BUFSIZE="${VIDEO_BUFSIZE:-8000k}"
GOP_SIZE="${GOP_SIZE:-60}"
AUDIO_BITRATE="${AUDIO_BITRATE:-160k}"
AUDIO_SAMPLE_RATE="${AUDIO_SAMPLE_RATE:-44100}"
ENFORCE_CBR="${ENFORCE_CBR:-0}"
FFMPEG_THREADS="${FFMPEG_THREADS:-2}"

build_rtmp_url() {
  if [[ -z "${YOUTUBE_STREAM_KEY:-}" ]]; then
    return 1
  fi
  local base="${YOUTUBE_RTMP_BASE:-rtmp://a.rtmp.youtube.com/live2}"
  base="${base%/}"
  local key="$(echo "$YOUTUBE_STREAM_KEY" | tr -d '[:space:]')"
  echo "${base}/${key}"
  return 0
}

start_healthcheck_server() {
  if [[ "${ENABLE_SERVER:-1}" != "1" ]]; then
    return
  fi
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    return
  fi
  python3 /app/server.py &>/dev/null &
  SERVER_PID=$!
}

cleanup() {
  rm -f "$PLAYLIST_FILE" "$CONCAT_LIST"
  if [[ -n "${SERVER_PID:-}" ]] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID"
  fi
}
trap cleanup EXIT

RTMP_URL=""
if build_rtmp_url >/dev/null 2>&1; then
  RTMP_URL="$(build_rtmp_url)"
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
  : > "$CONCAT_LIST"
  for file in "${MP3_FILES[@]}"; do
    printf "file '%s'\n" "$file" >> "$CONCAT_LIST"
  done
}

concat_mp3s() {
  ffmpeg -hide_banner -loglevel warning -f concat -safe 0 -i "$CONCAT_LIST" -c copy "$PLAYLIST_FILE"
}

build_ffmpeg_common_args() {
  local args=()
  args+=( -c:v libx264 -preset "${VIDEO_PRESET}" -tune stillimage )
  args+=( -b:v "${VIDEO_BITRATE}" -maxrate "${VIDEO_MAXRATE}" -bufsize "${VIDEO_BUFSIZE}" )
  args+=( -pix_fmt yuv420p -g "${GOP_SIZE}" -r "${VIDEO_FPS}" )
  args+=( -threads "${FFMPEG_THREADS}" )
  args+=( -vf "scale=${VIDEO_SCALE},setsar=1" )
  args+=( -c:a aac -b:a "${AUDIO_BITRATE}" -ar "${AUDIO_SAMPLE_RATE}" )
  echo "${args[@]}"
}

start_live() {
  echo "Preparando transmissão (PREVIEW=${PREVIEW})..."
  FF_ARGS=($(build_ffmpeg_common_args))

  if [[ "$PREVIEW" == "1" ]]; then
    PREVIEW_OUT="/tmp/preview_output_${CHANNEL_NAME:-preview}.mp4"
    echo "Modo PREVIEW: saída local $PREVIEW_OUT"
    ffmpeg -hide_banner -loglevel info -re \
      -stream_loop -1 -i "$PLAYLIST_FILE" \
      -stream_loop -1 -i "$VIDEO_FILE" \
      "${FF_ARGS[@]}" -f mp4 -y "$PREVIEW_OUT"
  else
    if [[ -z "$RTMP_URL" ]]; then
      echo "Erro: RTMP_URL não configurada (YOUTUBE_STREAM_KEY faltando)." >&2
      exit 1
    fi
    echo "Enviando para RTMP: $RTMP_URL"
    ffmpeg -hide_banner -loglevel info -re \
      -stream_loop -1 -i "$PLAYLIST_FILE" \
      -stream_loop -1 -i "$VIDEO_FILE" \
      "${FF_ARGS[@]}" -f flv "$RTMP_URL"
  fi
}

start_healthcheck_server

while true; do
  generate_concat_list
  concat_mp3s
  start_live
  echo "ffmpeg encerrou. Reiniciando em 2s..."
  sleep 2
done
