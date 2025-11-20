#!/usr/bin/env python3
"""
Dashboard para gerenciamento de lives lo-fi
"""
import os
import json
import time
import subprocess
import threading
import urllib.request
from datetime import datetime, timedelta
from pathlib import Path
from flask import Flask, render_template, request, jsonify, session, redirect, url_for
from flask_socketio import SocketIO, emit
from werkzeug.security import check_password_hash, generate_password_hash
from functools import wraps

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('DASHBOARD_SECRET_KEY', 'change-me-in-production-12345')
app.config['SESSION_COOKIE_HTTPONLY'] = True
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'

socketio = SocketIO(app, cors_allowed_origins="*")

# Configurações
DASHBOARD_USER = os.environ.get('DASHBOARD_USER', 'admin')
DASHBOARD_PASSWORD = os.environ.get('DASHBOARD_PASSWORD', 'admin123')
LOG_DIR = Path('/app/logs')
LOG_DIR.mkdir(parents=True, exist_ok=True)
CONTROL_DIR = Path('/app/control')
CONTROL_DIR.mkdir(parents=True, exist_ok=True)
STATS_DIR = Path('/app/stats')
STATS_DIR.mkdir(parents=True, exist_ok=True)

# Estado das lives
lives_status = {}

def login_required(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'logged_in' not in session:
            return jsonify({'error': 'Não autenticado'}), 401
        return f(*args, **kwargs)
    return decorated_function

@app.route('/')
def index():
    if 'logged_in' in session:
        return render_template('dashboard.html')
    return redirect(url_for('login'))

@app.route('/ip')
def show_ip():
    """Página pública que mostra apenas o IP para acesso"""
    server_info = get_cached_public_ip()
    local_ip = 'N/A'
    
    try:
        import socket
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        pass
    
    public_ip = server_info.get('ip', 'N/A') if server_info else 'N/A'
    
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>IP do Servidor - Dashboard Lo-Fi</title>
        <style>
            body {{
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
                margin: 0;
                padding: 20px;
            }}
            .container {{
                background: white;
                border-radius: 16px;
                padding: 40px;
                box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
                text-align: center;
                max-width: 500px;
            }}
            h1 {{
                color: #333;
                margin-bottom: 30px;
            }}
            .ip-box {{
                background: #f8f9fa;
                border: 2px solid #e0e0e0;
                border-radius: 8px;
                padding: 20px;
                margin: 20px 0;
            }}
            .ip-label {{
                font-size: 14px;
                color: #666;
                margin-bottom: 8px;
            }}
            .ip-value {{
                font-size: 24px;
                font-weight: 600;
                color: #667eea;
                word-break: break-all;
            }}
            .link {{
                display: inline-block;
                margin-top: 20px;
                padding: 12px 24px;
                background: #667eea;
                color: white;
                text-decoration: none;
                border-radius: 8px;
                font-weight: 600;
            }}
            .link:hover {{
                background: #5568d3;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🎵 Dashboard Lo-Fi</h1>
            <div class="ip-box">
                <div class="ip-label">IP Público</div>
                <div class="ip-value">{public_ip}</div>
            </div>
            <div class="ip-box">
                <div class="ip-label">IP Local</div>
                <div class="ip-value">{local_ip}</div>
            </div>
            <a href="http://{public_ip}:5000" class="link" target="_blank">
                Acessar Dashboard →
            </a>
            <p style="margin-top: 20px; color: #666; font-size: 14px;">
                Porta: 5000
            </p>
        </div>
    </body>
    </html>
    """

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        data = request.get_json()
        username = data.get('username', '')
        password = data.get('password', '')
        
        if username == DASHBOARD_USER and password == DASHBOARD_PASSWORD:
            session['logged_in'] = True
            session['username'] = username
            return jsonify({'success': True})
        else:
            return jsonify({'success': False, 'error': 'Credenciais inválidas'}), 401
    
    if 'logged_in' in session:
        return redirect(url_for('index'))
    return render_template('login.html')

@app.route('/logout')
def logout():
    session.clear()
    return redirect(url_for('login'))

@app.route('/api/channels')
@login_required
def get_channels():
    """Lista todos os canais disponíveis"""
    channels = []
    config_dir = Path('/app/config')
    
    if config_dir.exists():
        for env_file in config_dir.glob('*.env'):
            channel_name = env_file.stem
            if channel_name != 'example':
                channels.append({
                    'name': channel_name,
                    'status': get_channel_status(channel_name)
                })
    
    return jsonify({'channels': channels})

@app.route('/api/channel/<channel_name>/status')
@login_required
def get_channel_status_endpoint(channel_name):
    """Obtém status detalhado de um canal"""
    status = get_channel_status(channel_name)
    return jsonify(status)

@app.route('/api/channel/<channel_name>/stop', methods=['POST'])
@login_required
def stop_channel(channel_name):
    """Encerra a live de um canal"""
    control_file = CONTROL_DIR / f"{channel_name}_stop"
    control_file.touch()
    
    return jsonify({'success': True, 'message': f'Comando de encerramento enviado para {channel_name}'})

@app.route('/api/channel/<channel_name>/restart', methods=['POST'])
@login_required
def restart_channel(channel_name):
    """Reinicia a live de um canal"""
    control_file = CONTROL_DIR / f"{channel_name}_restart"
    control_file.touch()
    
    return jsonify({'success': True, 'message': f'Comando de reinício enviado para {channel_name}'})

def validate_config_value(key, value):
    """
    Valida valores de configuração antes de salvar.
    Retorna (is_valid, error_message)
    """
    if key == 'RESTART_HOUR':
        # RESTART_HOUR deve ser um inteiro entre 0-23
        # É usado em arithmetic expansion no entrypoint.sh, então deve ser numérico
        try:
            hour = int(value)
            if hour < 0 or hour > 23:
                return False, f'RESTART_HOUR deve ser um número entre 0 e 23, recebido: {value}'
        except (ValueError, TypeError):
            return False, f'RESTART_HOUR deve ser um número inteiro entre 0 e 23, recebido: {value}'
    
    elif key == 'VIDEO_FPS':
        # VIDEO_FPS deve ser um número inteiro válido
        try:
            fps = int(value)
            if fps < 1 or fps > 120:
                return False, f'VIDEO_FPS deve ser um número entre 1 e 120, recebido: {value}'
        except (ValueError, TypeError):
            return False, f'VIDEO_FPS deve ser um número inteiro, recebido: {value}'
    
    return True, None

@app.route('/api/channel/<channel_name>/config', methods=['GET', 'POST'])
@login_required
def channel_config(channel_name):
    """Obtém ou atualiza configuração de um canal"""
    config_file = Path(f'/app/config/{channel_name}.env')
    
    if request.method == 'GET':
        config = {}
        if config_file.exists():
            with open(config_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        config[key.strip()] = value.strip()
        return jsonify({'config': config})
    
    else:  # POST
        data = request.get_json()
        updates = data.get('updates', {})
        
        # Valida todos os valores antes de salvar
        for key, value in updates.items():
            is_valid, error_message = validate_config_value(key, value)
            if not is_valid:
                return jsonify({'success': False, 'error': error_message}), 400
        
        # Lê configuração atual
        lines = []
        if config_file.exists():
            with open(config_file, 'r') as f:
                lines = f.readlines()
        
        # Atualiza valores
        updated_keys = set()
        new_lines = []
        for line in lines:
            original_line = line
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key = line.split('=', 1)[0].strip()
                if key in updates:
                    new_lines.append(f"{key}={updates[key]}\n")
                    updated_keys.add(key)
                    continue
            new_lines.append(original_line)
        
        # Adiciona novas chaves
        for key, value in updates.items():
            if key not in updated_keys:
                new_lines.append(f"{key}={value}\n")
        
        # Salva arquivo
        with open(config_file, 'w') as f:
            f.writelines(new_lines)
        
        # Envia comando de reload
        reload_file = CONTROL_DIR / f"{channel_name}_reload"
        reload_file.touch()
        
        return jsonify({'success': True, 'message': 'Configuração atualizada'})

@app.route('/api/channel/<channel_name>/logs')
@login_required
def get_logs(channel_name):
    """Obtém logs de um canal"""
    log_file = LOG_DIR / f"{channel_name}.log"
    
    lines = request.args.get('lines', 100, type=int)
    
    if log_file.exists():
        # Lê últimas N linhas
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            all_lines = f.readlines()
            recent_lines = all_lines[-lines:] if len(all_lines) > lines else all_lines
            return jsonify({'logs': recent_lines, 'total': len(all_lines)})
    
    return jsonify({'logs': [], 'total': 0})

@app.route('/api/channel/<channel_name>/stats')
@login_required
def get_stats(channel_name):
    """Obtém estatísticas de um canal"""
    stats_file = STATS_DIR / f"{channel_name}.json"
    
    if stats_file.exists():
        try:
            with open(stats_file, 'r') as f:
                stats = json.load(f)
                return jsonify(stats)
        except:
            pass
    
    # Retorna estatísticas padrão
    return jsonify({
        'status': 'unknown',
        'uptime': 0,
        'current_video': 'N/A',
        'video_count': 0,
        'last_restart': None,
        'next_restart': None
    })

@app.route('/api/public-ip')
@login_required
def get_public_ip():
    """Obtém o IP público do servidor"""
    try:
        # Tenta vários serviços para obter o IP público
        services = [
            'https://api.ipify.org',
            'https://icanhazip.com',
            'https://ifconfig.me/ip',
            'https://checkip.amazonaws.com'
        ]
        
        for service in services:
            try:
                with urllib.request.urlopen(service, timeout=3) as response:
                    ip = response.read().decode('utf-8').strip()
                    if ip and '.' in ip:  # Validação básica de IP
                        return jsonify({
                            'success': True,
                            'ip': ip,
                            'dashboard_url': f'http://{ip}:5000'
                        })
            except:
                continue
        
        return jsonify({
            'success': False,
            'error': 'Não foi possível obter o IP público'
        }), 500
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500

@app.route('/api/server-info')
@login_required
def get_server_info():
    """Obtém informações do servidor"""
    import socket
    
    # IP local
    local_ip = 'N/A'
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except:
        pass
    
    # IP público (cache por 5 minutos)
    public_ip = get_cached_public_ip()
    
    return jsonify({
        'local_ip': local_ip,
        'public_ip': public_ip.get('ip', 'N/A') if public_ip else 'N/A',
        'dashboard_port': 5000,
        'local_url': f'http://{local_ip}:5000',
        'public_url': f'http://{public_ip.get("ip", "N/A")}:5000' if public_ip else 'N/A'
    })

# Cache para IP público (evita muitas requisições)
_public_ip_cache = {'ip': None, 'timestamp': 0}

def get_cached_public_ip():
    """Obtém IP público com cache de 5 minutos"""
    current_time = time.time()
    
    # Se o cache é válido, retorna
    if _public_ip_cache['ip'] and (current_time - _public_ip_cache['timestamp']) < 300:
        return {'ip': _public_ip_cache['ip'], 'cached': True}
    
    # Busca novo IP
    services = [
        'https://api.ipify.org',
        'https://icanhazip.com',
        'https://ifconfig.me/ip',
        'https://checkip.amazonaws.com'
    ]
    
    for service in services:
        try:
            with urllib.request.urlopen(service, timeout=3) as response:
                ip = response.read().decode('utf-8').strip()
                if ip and '.' in ip:
                    _public_ip_cache['ip'] = ip
                    _public_ip_cache['timestamp'] = current_time
                    return {'ip': ip, 'cached': False}
        except:
            continue
    
    return None

def get_channel_status(channel_name):
    """Obtém status de um canal com verificação robusta"""
    pid_file = Path(f'/app/ffmpeg_{channel_name}.pid')
    # Também verifica o caminho padrão usado pelo entrypoint
    if not pid_file.exists():
        pid_file = Path(f'/app/ffmpeg.pid')
    stats_file = STATS_DIR / f"{channel_name}.json"
    log_file = LOG_DIR / f"{channel_name}.log"
    
    status = {
        'name': channel_name,
        'running': False,
        'pid': None,
        'uptime': 0,
        'current_video': 'N/A',
        'streaming': False,  # Indica se está realmente transmitindo
        'last_activity': None
    }
    
    # Primeiro, carrega estatísticas do arquivo (atualizado pelo entrypoint)
    if stats_file.exists():
        try:
            with open(stats_file, 'r') as f:
                stats = json.load(f)
                # O entrypoint.sh já atualiza o status como "running" ou "stopped"
                if stats.get('status') == 'running':
                    status['running'] = True
                status.update(stats)
        except:
            pass
    
    # Verifica se o processo está rodando (verificação adicional)
    process_running = False
    pid = None
    if pid_file.exists():
        try:
            with open(pid_file, 'r') as f:
                pid = int(f.read().strip())
                # Verifica se o processo existe
                try:
                    os.kill(pid, 0)
                    process_running = True
                    status['pid'] = pid
                except OSError:
                    process_running = False
        except:
            process_running = False
    
    # Se o stats diz que está running mas o processo não existe, corrige
    if status.get('status') == 'running' and not process_running:
        status['running'] = False
        status['streaming'] = False
    elif process_running:
        status['running'] = True
    
    # Verifica logs recentes para confirmar transmissão ativa
    if log_file.exists() and status['running']:
        try:
            # Lê as últimas 50 linhas do log
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                recent_lines = lines[-50:] if len(lines) > 50 else lines
                
                # Procura por indicadores de transmissão ativa
                streaming_indicators = [
                    'Streaming to',
                    'rtmp://',
                    'frame=',
                    'fps=',
                    'bitrate=',
                    'speed=',
                    '[INFO] Stream iniciado',
                    '[INFO] Iniciando stream'
                ]
                
                # Procura por erros recentes
                error_indicators = [
                    'ERROR',
                    'Error',
                    'failed',
                    'Failed',
                    'Connection refused',
                    'Connection timed out',
                    'Network is unreachable'
                ]
                
                has_streaming_activity = False
                has_recent_errors = False
                last_activity_time = None
                
                for line in reversed(recent_lines):
                    # Verifica atividade de transmissão (últimas 2 minutos)
                    if any(indicator in line for indicator in streaming_indicators):
                        has_streaming_activity = True
                        # Tenta extrair timestamp
                        if '[' in line and ']' in line:
                            try:
                                timestamp_str = line.split('[')[1].split(']')[0]
                                last_activity_time = timestamp_str
                            except:
                                pass
                    
                    # Verifica erros recentes (últimas 10 linhas)
                    if len(recent_lines) - recent_lines.index(line) <= 10:
                        if any(indicator in line for indicator in error_indicators):
                            has_recent_errors = True
                
                # Se há atividade de transmissão e não há erros recentes, está transmitindo
                if has_streaming_activity and not has_recent_errors:
                    status['streaming'] = True
                elif has_recent_errors:
                    status['streaming'] = False
                    status['running'] = False  # Se há erros, considera offline
                
                if last_activity_time:
                    status['last_activity'] = last_activity_time
                    
        except Exception as e:
            # Se não conseguir ler logs, assume que está rodando se o processo existe
            status['streaming'] = status['running']
    
    # Se não há arquivo de log mas o processo está rodando, assume que está transmitindo
    if not log_file.exists() and status['running']:
        status['streaming'] = True
    
    return status

@socketio.on('connect')
def handle_connect():
    """Cliente conectado"""
    emit('connected', {'message': 'Conectado ao dashboard'})

@socketio.on('subscribe_logs')
def handle_subscribe_logs(data):
    """Cliente quer receber logs em tempo real"""
    channel_name = data.get('channel')
    if channel_name:
        # Envia logs iniciais
        log_file = LOG_DIR / f"{channel_name}.log"
        if log_file.exists():
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                emit('logs', {'channel': channel_name, 'lines': lines[-50:]})
        
        # Inicia thread para monitorar logs
        threading.Thread(
            target=monitor_logs,
            args=(channel_name,),
            daemon=True
        ).start()

def monitor_logs(channel_name):
    """Monitora logs de um canal e envia via WebSocket"""
    log_file = LOG_DIR / f"{channel_name}.log"
    last_position = 0
    
    if log_file.exists():
        last_position = log_file.stat().st_size
    
    while True:
        try:
            time.sleep(1)
            if log_file.exists():
                current_size = log_file.stat().st_size
                if current_size > last_position:
                    with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                        f.seek(last_position)
                        new_lines = f.readlines()
                        if new_lines:
                            socketio.emit('logs', {
                                'channel': channel_name,
                                'lines': new_lines
                            })
                    last_position = current_size
                elif current_size < last_position:
                    # Arquivo foi truncado ou recriado
                    last_position = 0
        except Exception as e:
            # Em caso de erro, aguarda e continua
            time.sleep(5)

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=False, allow_unsafe_werkzeug=True)

