#!/bin/bash
set -euo pipefail

APP_DIR="/app"
CHANNEL_NAME="${CHANNEL_NAME:-}"
CHANNEL_CONFIG_FILE="${CHANNEL_CONFIG_FILE:-}"

if [[ -n "$CHANNEL_NAME" ]]; then
  CHANNEL_CONFIG_FILE="${CHANNEL_CONFIG_FILE:-$APP_DIR/config/${CHANNEL_NAME}.env}"
fi

if [[ -n "$CHANNEL_CONFIG_FILE" && -f "$CHANNEL_CONFIG_FILE" ]]; then
  echo "Carregando configuração do canal '${CHANNEL_NAME:-default}' em '$CHANNEL_CONFIG_FILE'..."
  set -a
  source "$CHANNEL_CONFIG_FILE"
  set +a
elif [[ -n "$CHANNEL_CONFIG_FILE" && "$CHANNEL_CONFIG_FILE" != "-" ]]; then
  echo "Aviso: arquivo de configuração '$CHANNEL_CONFIG_FILE' não encontrado." >&2
fi

MP3_DIR="${MP3_DIR:-$APP_DIR/musicas}"
VIDEO_FILE="${VIDEO_FILE:-$APP_DIR/video.mp4}"
PLAYLIST_FILE="$APP_DIR/playlist_temp.mp3"
CONCAT_LIST="$APP_DIR/concat_list.txt"
RTMP_URL="${STREAM_URL:-}"
STREAM_KEY_FILE="${STREAM_KEY_FILE:-}"
VIDEO_SCALE="${VIDEO_SCALE:-1920:1080}"
VIDEO_FPS="${VIDEO_FPS:-30}"
FORCE_SQUARE_PIXELS="${FORCE_SQUARE_PIXELS:-1}"
VIDEO_PRESET="${VIDEO_PRESET:-superfast}"
VIDEO_BITRATE="${VIDEO_BITRATE:-4500k}"
VIDEO_MAXRATE="${VIDEO_MAXRATE:-5500k}"
VIDEO_BUFSIZE="${VIDEO_BUFSIZE:-8000k}"
GOP_SIZE="${GOP_SIZE:-60}"
AUDIO_BITRATE="${AUDIO_BITRATE:-160k}"
AUDIO_SAMPLE_RATE="${AUDIO_SAMPLE_RATE:-44100}"
ENFORCE_CBR="${ENFORCE_CBR:-0}"
FFMPEG_THREADS="${FFMPEG_THREADS:-2}"
VIDEO_SOURCE_URL="${VIDEO_SOURCE_URL:-}"
VIDEO_DOWNLOAD_RETRIES="${VIDEO_DOWNLOAD_RETRIES:-3}"
VIDEO_DOWNLOAD_TIMEOUT="${VIDEO_DOWNLOAD_TIMEOUT:-300}"

build_rtmp_url() {
  local file_key=""

  if [[ -n "$STREAM_KEY_FILE" ]]; then
    if [[ -f "$STREAM_KEY_FILE" ]]; then
      file_key="$(<"$STREAM_KEY_FILE")"
    else
      echo "Erro: arquivo definido em STREAM_KEY_FILE ('${STREAM_KEY_FILE}') não encontrado." >&2
      exit 1
    fi
  fi

  local stream_key="${file_key:-${YOUTUBE_STREAM_KEY:-${STREAM_KEY:-${STREAMKEY:-}}}}"
  local base_url="${YOUTUBE_RTMP_BASE:-rtmp://a.rtmp.youtube.com/live2}"

  if [[ -n "$stream_key" ]]; then
    # remove sufixos "/" duplicados
    base_url="${base_url%/}"
    stream_key="$(printf '%s' "$stream_key" | tr -d '[:space:]')"
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

ensure_video_file() {
  if [[ -z "$VIDEO_SOURCE_URL" ]]; then
    return
  fi

  echo "Baixando vídeo de '${VIDEO_SOURCE_URL}'..."
  local tmp_file="${VIDEO_FILE}.download"
  mkdir -p "$(dirname "$VIDEO_FILE")"

  if curl -fL --connect-timeout 15 --max-time "$VIDEO_DOWNLOAD_TIMEOUT" \
         --retry "$VIDEO_DOWNLOAD_RETRIES" --retry-delay 2 \
         -o "$tmp_file" "$VIDEO_SOURCE_URL"; then
    mv "$tmp_file" "$VIDEO_FILE"
    echo "Vídeo salvo em '$VIDEO_FILE'."
  else
    echo "Erro ao baixar vídeo de '${VIDEO_SOURCE_URL}'." >&2
    rm -f "$tmp_file"
    exit 1
  fi
}

ensure_video_file

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

build_video_filters() {
  local filters=()

  if [[ -n "$VIDEO_SCALE" ]]; then
    filters+=("scale=${VIDEO_SCALE}")
  fi

  if [[ "$FORCE_SQUARE_PIXELS" == "1" ]]; then
    filters+=("setsar=1")
  fi

  if [[ -n "${VIDEO_FILTER_EXTRA:-}" ]]; then
    filters+=("${VIDEO_FILTER_EXTRA}")
  fi

  if (( ${#filters[@]} > 0 )); then
    VIDEO_FILTER_ARGS=(-vf "$(IFS=','; echo "${filters[*]}")")
  else
    VIDEO_FILTER_ARGS=()
  fi
}

start_live() {
  echo "Iniciando live para '$RTMP_URL'..."
  build_video_filters

  ffmpeg -hide_banner -loglevel info -re \
         -stream_loop -1 -i "$PLAYLIST_FILE" \
         -stream_loop -1 -i "$VIDEO_FILE" \
         -c:v libx264 -preset "${VIDEO_PRESET}" -tune stillimage \
         -b:v "${VIDEO_BITRATE}" -maxrate "${VIDEO_MAXRATE}" -bufsize "${VIDEO_BUFSIZE}" \
         -pix_fmt yuv420p -g "${GOP_SIZE}" -r "${VIDEO_FPS}" \
         -threads "${FFMPEG_THREADS}" \
         "${VIDEO_FILTER_ARGS[@]}" \
         -c:a aac -b:a "${AUDIO_BITRATE}" -ar "${AUDIO_SAMPLE_RATE}" \
         $( (( ENFORCE_CBR == 1 )) && printf '%s' "-muxdelay 0 -muxpreload 0.5" ) \
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
