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
VIDEO_DIR="${VIDEO_DIR:-$APP_DIR/video}"
PLAYLIST_FILE="$APP_DIR/playlist_temp.mp3"
CONCAT_LIST="$APP_DIR/concat_list.txt"
FFMPEG_PID_FILE="$APP_DIR/ffmpeg_${CHANNEL_NAME}.pid"
LOG_FILE="$APP_DIR/logs/${CHANNEL_NAME}.log"
STATS_FILE="$APP_DIR/stats/${CHANNEL_NAME}.json"
CONTROL_DIR="$APP_DIR/control"
STREAM_START_TIME=""

# Cria diretórios necessários
mkdir -p "$APP_DIR/logs" "$APP_DIR/stats" "$CONTROL_DIR"

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

# Hora para encerrar e reiniciar a live (formato: HH, ex: 12, ou 0-23)
RESTART_HOUR="${RESTART_HOUR:-12}"
# Remove zero à esquerda se houver (ex: "09" vira "9") e valida como número
RESTART_HOUR=$((10#$RESTART_HOUR))

build_rtmp_url() {
  [[ -z "${YOUTUBE_STREAM_KEY:-}" ]] && return 1
  local base="${YOUTUBE_RTMP_BASE:-rtmp://a.rtmp.youtube.com/live2}"
  base="${base%/}"
  echo "${base}/${YOUTUBE_STREAM_KEY}"
  return 0
}

# Função para log
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Função para atualizar estatísticas
update_stats() {
  local uptime=0
  if [[ -n "$STREAM_START_TIME" ]] && [[ "$STREAM_START_TIME" =~ ^[0-9]+$ ]]; then
    uptime=$(($(date +%s) - STREAM_START_TIME))
  fi
  
  local status="stopped"
  if [[ -f "$FFMPEG_PID_FILE" ]]; then
    local pid=$(cat "$FFMPEG_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      status="running"
    fi
  fi
  
  local current_video_name="N/A"
  if [[ -n "${VIDEO_FILE:-}" ]] && [[ -f "${VIDEO_FILE}" ]]; then
    current_video_name=$(basename "$VIDEO_FILE")
  fi
  
  # Conta vídeos do canal
  local video_count=0
  shopt -s nullglob
  local channel_videos=("$VIDEO_DIR/${CHANNEL_NAME}_"*.mp4)
  shopt -u nullglob
  video_count=${#channel_videos[@]}
  
  # Se não encontrou vídeos com padrão, verifica padrão antigo
  if [[ $video_count -eq 0 ]] && [[ -f "$VIDEO_DIR/${CHANNEL_NAME}.mp4" ]]; then
    video_count=1
  fi
  
  cat > "$STATS_FILE" <<EOF
{
  "status": "$status",
  "uptime": $uptime,
  "current_video": "$current_video_name",
  "video_count": $video_count,
  "last_restart": "$(date '+%Y-%m-%dT%H:%M:%S%z')",
  "next_restart": "N/A"
}
EOF
}

start_healthcheck_server() {
  python3 /app/server.py &>/dev/null &
  SERVER_PID=$!
}

# Verifica comandos de controle
check_control_commands() {
  local stop_file="$CONTROL_DIR/${CHANNEL_NAME}_stop"
  local restart_file="$CONTROL_DIR/${CHANNEL_NAME}_restart"
  local reload_file="$CONTROL_DIR/${CHANNEL_NAME}_reload"
  
  if [[ -f "$stop_file" ]]; then
    log "INFO" "Comando de encerramento recebido"
    rm -f "$stop_file"
    stop_ffmpeg
    return 1
  fi
  
  if [[ -f "$restart_file" ]]; then
    log "INFO" "Comando de reinício recebido"
    rm -f "$restart_file"
    stop_ffmpeg
    sleep 2
    return 1
  fi
  
  if [[ -f "$reload_file" ]]; then
    log "INFO" "Comando de recarregar configuração recebido"
    rm -f "$reload_file"
    # Recarrega configuração
    set -a
    source "$CHANNEL_CONFIG_FILE"
    set +a
    log "INFO" "Configuração recarregada"
  fi
  
  return 0
}

# Função para selecionar o vídeo a ser usado
# Filtra vídeos pelo nome do canal (ex: cozy_1.mp4, cozy_2.mp4 para canal "cozy")
select_video() {
  local video_file=""
  
  # Se VIDEO_FILE estiver definido explicitamente, usa ele
  if [[ -n "${VIDEO_FILE:-}" ]] && [[ -f "${VIDEO_FILE}" ]]; then
    echo "${VIDEO_FILE}"
    return 0
  fi
  
  # Procura vídeos que correspondem ao padrão do canal: ${CHANNEL_NAME}_*.mp4
  shopt -s nullglob
  local channel_videos=("$VIDEO_DIR/${CHANNEL_NAME}_"*.mp4)
  shopt -u nullglob
  
  # Se não encontrou vídeos com o padrão do canal, tenta o padrão antigo: ${CHANNEL_NAME}.mp4
  if [[ ${#channel_videos[@]} -eq 0 ]]; then
    local fallback_video="$VIDEO_DIR/${CHANNEL_NAME}.mp4"
    if [[ -f "$fallback_video" ]]; then
      echo "$fallback_video"
      return 0
    else
      echo "[ERRO] Nenhum vídeo encontrado para o canal '${CHANNEL_NAME}'" >&2
      echo "[ERRO] Procurando por: ${CHANNEL_NAME}_*.mp4 ou ${CHANNEL_NAME}.mp4" >&2
      exit 1
    fi
  fi
  
  # Se houver apenas um vídeo do canal, usa ele
  if [[ ${#channel_videos[@]} -eq 1 ]]; then
    video_file="${channel_videos[0]}"
    echo "[INFO] Usando vídeo: $(basename "$video_file")" >&2
  else
    # Se houver múltiplos vídeos do canal, rotaciona entre eles
    local state_file="$APP_DIR/video_state_${CHANNEL_NAME}.txt"
    local current_index=0
    local video_count=${#channel_videos[@]}
    
    if [[ -f "$state_file" ]]; then
      current_index=$(cat "$state_file" 2>/dev/null || echo "0")
      current_index=$((current_index + 1))
    fi
    
    # Rotaciona entre os vídeos disponíveis do canal
    current_index=$((current_index % video_count))
    video_file="${channel_videos[$current_index]}"
    
    # Salva o índice para a próxima vez
    echo "$current_index" > "$state_file"
    
    echo "[INFO] Selecionado vídeo: $(basename "$video_file") (${current_index}/${video_count})" >&2
  fi
  
  echo "$video_file"
}

# Verifica se é hora de reiniciar
should_restart() {
  local current_hour=$(date +%H)
  local current_minute=$(date +%M)
  
  # Remove zero à esquerda para comparação (ex: "09" vira "9")
  current_hour=$((10#$current_hour))
  local restart_hour=$((10#$RESTART_HOUR))
  current_minute=$((10#$current_minute))
  
  # Reinicia se for exatamente a hora configurada e estiver nos primeiros 2 minutos
  # Isso garante que capture a hora mesmo se houver pequeno atraso
  if [[ $current_hour -eq $restart_hour ]] && [[ $current_minute -lt 2 ]]; then
    return 0
  fi
  
  return 1
}

# Encerra o FFmpeg graciosamente
stop_ffmpeg() {
  if [[ -f "$FFMPEG_PID_FILE" ]]; then
    local pid=$(cat "$FFMPEG_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      echo "[INFO] Encerrando stream atual (PID: $pid)..." >&2
      # Envia SIGTERM para encerrar graciosamente
      kill -TERM "$pid" 2>/dev/null || true
      
      # Aguarda até 30 segundos para o processo terminar
      local count=0
      while kill -0 "$pid" 2>/dev/null && [[ $count -lt 30 ]]; do
        sleep 1
        count=$((count + 1))
      done
      
      # Se ainda estiver rodando, força o encerramento
      if kill -0 "$pid" 2>/dev/null; then
        echo "[WARN] Forçando encerramento do FFmpeg..." >&2
        kill -KILL "$pid" 2>/dev/null || true
      fi
      
      rm -f "$FFMPEG_PID_FILE"
      echo "[INFO] Stream encerrado." >&2
      sleep 2
    fi
  fi
}

cleanup() {
  stop_ffmpeg
  rm -f "$PLAYLIST_FILE" "$CONCAT_LIST" "$FFMPEG_PID_FILE"
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT

RTMP_URL="$(build_rtmp_url || echo "")"

[[ ! -d "$MP3_DIR" ]] && echo "Erro: MP3_DIR inválido" && exit 1
[[ ! -d "$VIDEO_DIR" ]] && echo "Erro: VIDEO_DIR inválido" && exit 1

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

# Variável para rastrear se já reiniciamos nesta hora
LAST_RESTART_TIME=""

log "INFO" "Iniciando sistema de streaming para canal: $CHANNEL_NAME"

# Loop principal
while true; do
  # Verifica comandos de controle
  if ! check_control_commands; then
    # Comando de stop ou restart foi recebido
    if [[ -f "$CONTROL_DIR/${CHANNEL_NAME}_stop" ]]; then
      log "INFO" "Live encerrada por comando"
      break
    fi
    # Se foi restart, continua o loop para reiniciar
  fi
  
  # Verifica se é hora de reiniciar
  local current_datetime_hour=$(date '+%Y-%m-%d-%H')
  if should_restart && [[ "$LAST_RESTART_TIME" != "$current_datetime_hour" ]]; then
    log "INFO" "Hora de reiniciar a live (${RESTART_HOUR}h)..."
    stop_ffmpeg
    LAST_RESTART_TIME="$current_datetime_hour"
    
    # Aguarda alguns segundos antes de reiniciar
    sleep 5
  fi
  
  # Seleciona o vídeo a ser usado
  VIDEO_FILE=$(select_video)
  
  if [[ ! -f "$VIDEO_FILE" ]]; then
    log "ERRO" "Vídeo não encontrado: $VIDEO_FILE"
    sleep 10
    continue
  fi
  
  log "INFO" "Iniciando stream com vídeo: $(basename "$VIDEO_FILE")"
  STREAM_START_TIME=$(date +%s)
  update_stats
  
  # Inicia o FFmpeg em background e salva o PID
  if [[ "$PREVIEW" == "1" ]]; then
    ffmpeg -re -stream_loop -1 -i "$PLAYLIST_FILE" \
      -stream_loop -1 -i "$VIDEO_FILE" \
      "${FF_ARGS[@]}" -f mp4 -y "/tmp/preview_${CHANNEL_NAME}.mp4" 2>&1 | while IFS= read -r line; do
        log "FFMPEG" "$line"
      done &
  else
    ffmpeg -re -stream_loop -1 -i "$PLAYLIST_FILE" \
      -stream_loop -1 -i "$VIDEO_FILE" \
      "${FF_ARGS[@]}" -f flv "$RTMP_URL" 2>&1 | while IFS= read -r line; do
        log "FFMPEG" "$line"
      done &
  fi
  
  FFMPEG_PID=$!
  echo "$FFMPEG_PID" > "$FFMPEG_PID_FILE"
  log "INFO" "FFmpeg iniciado com PID: $FFMPEG_PID"
  
  # Monitora o processo FFmpeg e verifica a hora periodicamente
  while kill -0 "$FFMPEG_PID" 2>/dev/null; do
    sleep 60  # Verifica a cada minuto
    
    # Atualiza estatísticas
    update_stats
    
    # Verifica comandos de controle
    if ! check_control_commands; then
      break
    fi
    
    # Se for hora de reiniciar, sai do loop interno
    local current_datetime_hour=$(date '+%Y-%m-%d-%H')
    if should_restart && [[ "$LAST_RESTART_TIME" != "$current_datetime_hour" ]]; then
      log "INFO" "Detectada hora de reinício durante monitoramento"
      break
    fi
  done
  
  # Se o FFmpeg terminou por erro, aguarda antes de reiniciar
  if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
    log "WARN" "FFmpeg terminou inesperadamente. Reiniciando em 5 segundos..."
    sleep 5
  fi
  
  rm -f "$FFMPEG_PID_FILE"
  update_stats
done

log "INFO" "Sistema encerrado"
