#!/bin/bash
set -euo pipefail

APP_DIR="/app"
CHANNEL_NAME="${CHANNEL_NAME:-}"
CHANNEL_CONFIG_FILE="${CHANNEL_CONFIG_FILE:-}"
PREVIEW="${PREVIEW:-0}"

if [[ -n "$CHANNEL_NAME" ]]; then
  CHANNEL_CONFIG_FILE="${CHANNEL_CONFIG_FILE:-$APP_DIR/config/${CHANNEL_NAME}.env}"
fi

if [[ ! -f "$CHANNEL_CONFIG_FILE" ]]; then
  echo "Erro: config '$CHANNEL_CONFIG_FILE' não encontrado."
  exit 1
fi

set -a
source "$CHANNEL_CONFIG_FILE"
set +a

MP3_DIR="${MP3_DIR:-$APP_DIR/musicas}"
VIDEO_FILE="${VIDEO_FILE:-$APP_DIR/video/${CHANNEL_NAME}.mp4}"
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
FFMPEG_THREADS="${FFMPEG_THREADS:-2}"

build_rtmp_url() {
  [[ -z "${YOUTUBE_STREAM_KEY:-}" ]] && return 1
  local base="${YOUTUBE_RTMP_BASE:-rtmp://a.rtmp.youtube.com/live2}"
  base="${base%/}"
  echo "${base}/${YOUTUBE_STREAM_KEY}"
  return 0
}

start_healthcheck_server() {
  python3 /app/server.py &>/dev/null &
  SERVER_PID=$!
}

cleanup() {
  rm -f "$PLAYLIST_FILE" "$CONCAT_LIST"
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

RTMP_URL="$(build_rtmp_url || echo "")"

[[ ! -d "$MP3_DIR" ]] && echo "Erro: MP3_DIR inválido" && exit 1
[[ ! -f "$VIDEO_FILE" ]] && echo "Erro: vídeo inválido" && exit 1

shopt -s nullglob
MP3_FILES=("$MP3_DIR"/*.mp3)
shopt -u nullglob

[[ ${#MP3_FILES[@]} -eq 0 ]] && echo "Erro: sem MP3s" && exit 1

generate_playlist() {
  echo "" > "$CONCAT_LIST"
  for file in "${MP3_FILES[@]}"; do
    echo "file '$file'" >> "$CONCAT_LIST"
  done
  ffmpeg -hide_banner -loglevel warning -f concat -safe 0 \
    -i "$CONCAT_LIST" -c copy "$PLAYLIST_FILE"
}

FF_ARGS=(
  -c:v libx264 -preset "$VIDEO_PRESET" -tune stillimage
  -b:v "$VIDEO_BITRATE" -maxrate "$VIDEO_MAXRATE" -bufsize "$VIDEO_BUFSIZE"
  -pix_fmt yuv420p -g "$GOP_SIZE" -r "$VIDEO_FPS"
  -threads "$FFMPEG_THREADS"
  -vf "scale=$VIDEO_SCALE,setsar=1"
  -c:a aac -b:a "$AUDIO_BITRATE" -ar "$AUDIO_SAMPLE_RATE"
)

start_healthcheck_server
generate_playlist

while true; do
  if [[ "$PREVIEW" == "1" ]]; then
    ffmpeg -re -stream_loop -1 -i "$PLAYLIST_FILE" \
      -stream_loop -1 -i "$VIDEO_FILE" \
      "${FF_ARGS[@]}" -f mp4 -y "/tmp/preview_${CHANNEL_NAME}.mp4"
  else
    ffmpeg -re -stream_loop -1 -i "$PLAYLIST_FILE" \
      -stream_loop -1 -i "$VIDEO_FILE" \
      "${FF_ARGS[@]}" -f flv "$RTMP_URL"
  fi
  sleep 2
done
