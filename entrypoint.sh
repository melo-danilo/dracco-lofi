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
# Retorna: 0 = continua normal, 1 = stop (encerra), 2 = restart (reinicia)
check_control_commands() {
  local stop_file="$CONTROL_DIR/${CHANNEL_NAME}_stop"
  local restart_file="$CONTROL_DIR/${CHANNEL_NAME}_restart"
  local reload_file="$CONTROL_DIR/${CHANNEL_NAME}_reload"
  
  # Verifica se o diretório de controle existe
  if [[ ! -d "$CONTROL_DIR" ]]; then
    mkdir -p "$CONTROL_DIR"
  fi
  
  if [[ -f "$stop_file" ]]; then
    log "INFO" "Comando de encerramento recebido (arquivo: $stop_file)"
    rm -f "$stop_file"
    stop_ffmpeg
    return 1  # Stop - encerra completamente
  fi
  
  if [[ -f "$restart_file" ]]; then
    log "INFO" "Comando de reinício recebido - encerrando transmissão atual... (arquivo: $restart_file)"
    rm -f "$restart_file"
    stop_ffmpeg
    # Aguarda alguns segundos para garantir que a transmissão foi completamente encerrada
    # (como o YouTube Studio faz - encerra completamente antes de iniciar nova)
    sleep 3
    log "INFO" "Transmissão encerrada. Iniciando nova transmissão..."
    return 2  # Restart - reinicia
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
  
  return 0  # Continua normal
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

# Encerra o FFmpeg graciosamente e força encerramento de processos filhos
stop_ffmpeg() {
  if [[ -f "$FFMPEG_PID_FILE" ]]; then
    local pid=$(cat "$FFMPEG_PID_FILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      log "INFO" "Encerrando stream atual (PID: $pid)..."
      
      # Envia SIGTERM para encerrar graciosamente
      kill -TERM "$pid" 2>/dev/null || true
      
      # Aguarda até 10 segundos para o processo terminar
      local count=0
      while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
        sleep 1
        count=$((count + 1))
      done
      
      # Se ainda estiver rodando, força o encerramento
      if kill -0 "$pid" 2>/dev/null; then
        log "WARN" "Forçando encerramento do FFmpeg (PID: $pid)..."
        # Mata o processo e todos os seus filhos
        pkill -TERM -P "$pid" 2>/dev/null || true
        sleep 1
        kill -KILL "$pid" 2>/dev/null || true
        pkill -KILL -P "$pid" 2>/dev/null || true
      fi
      
      # Aguarda um pouco mais para garantir que todos os processos terminaram
      sleep 2
      
      # Verifica se ainda há processos FFmpeg rodando para este canal
      local remaining_pids=$(pgrep -f "ffmpeg.*${CHANNEL_NAME}" 2>/dev/null || echo "")
      if [[ -n "$remaining_pids" ]]; then
        log "WARN" "Encerrando processos FFmpeg remanescentes: $remaining_pids"
        echo "$remaining_pids" | xargs kill -KILL 2>/dev/null || true
        sleep 1
      fi
      
      rm -f "$FFMPEG_PID_FILE"
      log "INFO" "Stream completamente encerrado."
    else
      # Se o PID não existe ou não está rodando, limpa o arquivo mesmo assim
      rm -f "$FFMPEG_PID_FILE"
    fi
  fi
  
  # Garante que não há processos FFmpeg órfãos rodando para esta URL RTMP
  if [[ -n "${RTMP_URL:-}" ]]; then
    local orphan_pids=$(pgrep -f "ffmpeg.*${RTMP_URL}" 2>/dev/null || echo "")
    if [[ -n "$orphan_pids" ]]; then
      log "WARN" "Encerrando processos FFmpeg órfãos para RTMP: $orphan_pids"
      echo "$orphan_pids" | xargs kill -KILL 2>/dev/null || true
      sleep 1
    fi
    
    # Também verifica processos FFmpeg que estão enviando para o mesmo stream key
    if [[ -n "${YOUTUBE_STREAM_KEY:-}" ]]; then
      local stream_key_pids=$(pgrep -f "ffmpeg.*${YOUTUBE_STREAM_KEY}" 2>/dev/null || echo "")
      if [[ -n "$stream_key_pids" ]]; then
        log "WARN" "Encerrando processos FFmpeg com mesmo stream key: $stream_key_pids"
        echo "$stream_key_pids" | xargs kill -KILL 2>/dev/null || true
        sleep 1
      fi
    fi
  fi
  
  # Verificação final: garante que não há nenhum processo FFmpeg relacionado
  local all_ffmpeg_pids=$(pgrep -f "^ffmpeg.*flv.*rtmp" 2>/dev/null || echo "")
  if [[ -n "$all_ffmpeg_pids" ]]; then
    # Verifica se algum desses processos está relacionado a este canal
    for check_pid in $all_ffmpeg_pids; do
      if ps -p "$check_pid" -o cmd= 2>/dev/null | grep -q "${CHANNEL_NAME}\|${RTMP_URL}"; then
        log "WARN" "Encerrando processo FFmpeg relacionado encontrado: $check_pid"
        kill -KILL "$check_pid" 2>/dev/null || true
      fi
    done
    sleep 1
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
  # Verifica comandos de controle ANTES de iniciar nova transmissão
  check_control_commands
  control_result=$?
  
  if [[ $control_result -eq 1 ]]; then
    # Comando de stop foi recebido - encerra completamente
    log "INFO" "Live encerrada por comando de stop"
    # Garante que o FFmpeg está encerrado
    stop_ffmpeg
    break
  elif [[ $control_result -eq 2 ]]; then
    # Comando de restart foi recebido - continua o loop para reiniciar
    # O stop_ffmpeg já foi chamado e aguardou 3 segundos
    # Aguarda mais um pouco para garantir encerramento completo antes de reiniciar
    sleep 2
    log "INFO" "Reiniciando live - iniciando nova transmissão..."
    # Continua o loop para iniciar nova transmissão (como YouTube Studio)
  fi
  
  # Verifica se é hora de reiniciar
  current_datetime_hour=$(date '+%Y-%m-%d-%H')
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
  
  # Garante que não há processos FFmpeg rodando antes de iniciar novo
  stop_ffmpeg
  
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
  
  # Monitora o processo FFmpeg e verifica comandos de controle frequentemente
  while kill -0 "$FFMPEG_PID" 2>/dev/null; do
    # Verifica comandos de controle a cada 5 segundos (mais responsivo)
    for i in {1..12}; do  # 12 x 5 segundos = 60 segundos total
      sleep 5
      
      # Verifica comandos de controle
      check_control_commands
      local control_result=$?
      
      if [[ $control_result -eq 1 ]]; then
        # Stop - encerra completamente
        stop_ffmpeg
        break 2  # Sai dos dois loops (for e while)
      elif [[ $control_result -eq 2 ]]; then
        # Restart - encerra e sai do loop interno para reiniciar
        stop_ffmpeg
        # Aguarda mais um pouco para garantir encerramento completo
        sleep 2
        break 2  # Sai dos dois loops (for e while)
      fi
      
      # Se o FFmpeg terminou, sai do loop interno
      if ! kill -0 "$FFMPEG_PID" 2>/dev/null; then
        break
      fi
    done
    
    # Atualiza estatísticas a cada minuto (após 12 verificações de 5 segundos)
    update_stats
    
    # Se for hora de reiniciar, sai do loop interno
    local current_datetime_hour=$(date '+%Y-%m-%d-%H')
    if should_restart && [[ "$LAST_RESTART_TIME" != "$current_datetime_hour" ]]; then
      log "INFO" "Detectada hora de reinício durante monitoramento"
      stop_ffmpeg
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
