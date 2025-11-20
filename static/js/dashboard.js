let currentChannel = null;
let socket = null;
let statsInterval = null;
let logsInterval = null;

// Inicialização
document.addEventListener('DOMContentLoaded', () => {
    loadChannels();
    connectWebSocket();
    loadServerInfo();
});

// Conecta ao WebSocket
function connectWebSocket() {
    socket = io();
    
    socket.on('connect', () => {
        console.log('Conectado ao servidor');
    });
    
    socket.on('logs', (data) => {
        if (data.channel === currentChannel) {
            appendLogs(data.lines);
        }
    });
}

// Carrega lista de canais
async function loadChannels() {
    try {
        const response = await fetch('/api/channels');
        const data = await response.json();
        
        const channelsList = document.getElementById('channelsList');
        channelsList.innerHTML = '';
        
        data.channels.forEach(channel => {
            const card = createChannelCard(channel);
            channelsList.appendChild(card);
        });
    } catch (error) {
        console.error('Erro ao carregar canais:', error);
    }
}

// Cria card de canal
function createChannelCard(channel) {
    const card = document.createElement('div');
    card.className = 'channel-card';
    card.onclick = () => showChannelDetails(channel.name);
    
    const statusClass = channel.status.running ? 'running' : 'stopped';
    const statusText = channel.status.running ? 'Online' : 'Offline';
    
    card.innerHTML = `
        <div class="channel-name">${channel.name}</div>
        <div class="channel-status">
            <span class="status-indicator ${statusClass}"></span>
            <span>${statusText}</span>
        </div>
    `;
    
    return card;
}

// Mostra detalhes do canal
async function showChannelDetails(channelName) {
    currentChannel = channelName;
    
    // Ativa card selecionado
    document.querySelectorAll('.channel-card').forEach(card => {
        card.classList.remove('active');
        if (card.querySelector('.channel-name').textContent === channelName) {
            card.classList.add('active');
        }
    });
    
    // Mostra seção de detalhes
    const detailsSection = document.getElementById('detailsSection');
    detailsSection.style.display = 'block';
    document.getElementById('channelTitle').textContent = `Canal: ${channelName}`;
    
    // Mostra aba de status
    showTab('status');
    
    // Carrega dados
    loadChannelStatus();
    loadChannelConfig();
    loadChannelLogs();
    
    // Inscreve em logs
    if (socket) {
        socket.emit('subscribe_logs', { channel: channelName });
    }
    
    // Inicia atualização periódica
    if (statsInterval) clearInterval(statsInterval);
    statsInterval = setInterval(loadChannelStatus, 5000);
}

// Fecha detalhes
function closeDetails() {
    currentChannel = null;
    document.getElementById('detailsSection').style.display = 'none';
    if (statsInterval) {
        clearInterval(statsInterval);
        statsInterval = null;
    }
}

// Mostra aba
function showTab(tabName) {
    // Esconde todas as abas
    document.querySelectorAll('.tab-content').forEach(tab => {
        tab.style.display = 'none';
    });
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.remove('active');
    });
    
    // Mostra aba selecionada
    document.getElementById(`tab${tabName.charAt(0).toUpperCase() + tabName.slice(1)}`).style.display = 'block';
    
    // Ativa botão da aba
    const buttons = document.querySelectorAll('.tab-btn');
    buttons.forEach((btn, index) => {
        const tabNames = ['status', 'config', 'logs'];
        if (tabNames[index] === tabName) {
            btn.classList.add('active');
        }
    });
    
    // Recarrega dados se necessário
    if (tabName === 'logs') {
        loadChannelLogs();
    }
}

// Carrega status do canal
async function loadChannelStatus() {
    if (!currentChannel) return;
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/status`);
        const status = await response.json();
        
        document.getElementById('statusValue').textContent = status.running ? '🟢 Online' : '🔴 Offline';
        document.getElementById('uptimeValue').textContent = formatUptime(status.uptime || 0);
        document.getElementById('currentVideo').textContent = status.current_video || 'N/A';
        document.getElementById('nextRestart').textContent = status.next_restart || 'N/A';
    } catch (error) {
        console.error('Erro ao carregar status:', error);
    }
}

// Carrega estatísticas
async function loadChannelStats() {
    if (!currentChannel) return;
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/stats`);
        const stats = await response.json();
        
        // Atualiza UI com estatísticas
        return stats;
    } catch (error) {
        console.error('Erro ao carregar estatísticas:', error);
    }
}

// Carrega configuração do canal
async function loadChannelConfig() {
    if (!currentChannel) return;
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/config`);
        const data = await response.json();
        const config = data.config;
        
        document.getElementById('restartHour').value = config.RESTART_HOUR || '12';
        document.getElementById('videoBitrate').value = config.VIDEO_BITRATE || '4500k';
        document.getElementById('audioBitrate').value = config.AUDIO_BITRATE || '160k';
        document.getElementById('videoFps').value = config.VIDEO_FPS || '30';
        document.getElementById('videoScale').value = config.VIDEO_SCALE || '1920:1080';
    } catch (error) {
        console.error('Erro ao carregar configuração:', error);
    }
}

// Salva configuração
document.getElementById('configForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    
    if (!currentChannel) return;
    
    const updates = {
        RESTART_HOUR: document.getElementById('restartHour').value,
        VIDEO_BITRATE: document.getElementById('videoBitrate').value,
        AUDIO_BITRATE: document.getElementById('audioBitrate').value,
        VIDEO_FPS: document.getElementById('videoFps').value,
        VIDEO_SCALE: document.getElementById('videoScale').value
    };
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/config`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ updates })
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('Configuração salva com sucesso!');
        } else {
            alert('Erro ao salvar configuração');
        }
    } catch (error) {
        console.error('Erro ao salvar configuração:', error);
        alert('Erro ao salvar configuração');
    }
});

// Encerra canal
async function stopChannel() {
    if (!currentChannel) return;
    if (!confirm(`Tem certeza que deseja encerrar a live do canal ${currentChannel}?`)) return;
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/stop`, {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('Comando de encerramento enviado!');
            setTimeout(loadChannelStatus, 2000);
        } else {
            alert('Erro ao encerrar live');
        }
    } catch (error) {
        console.error('Erro ao encerrar canal:', error);
        alert('Erro ao encerrar live');
    }
}

// Reinicia canal
async function restartChannel() {
    if (!currentChannel) return;
    if (!confirm(`Tem certeza que deseja reiniciar a live do canal ${currentChannel}?`)) return;
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/restart`, {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (data.success) {
            alert('Comando de reinício enviado!');
            setTimeout(loadChannelStatus, 2000);
        } else {
            alert('Erro ao reiniciar live');
        }
    } catch (error) {
        console.error('Erro ao reiniciar canal:', error);
        alert('Erro ao reiniciar live');
    }
}

// Carrega logs
async function loadChannelLogs() {
    if (!currentChannel) return;
    
    try {
        const response = await fetch(`/api/channel/${currentChannel}/logs?lines=100`);
        const data = await response.json();
        
        const logsContent = document.getElementById('logsContent');
        logsContent.innerHTML = '';
        
        data.logs.forEach(line => {
            appendLogLine(line);
        });
        
        // Scroll para o final
        logsContent.scrollTop = logsContent.scrollHeight;
    } catch (error) {
        console.error('Erro ao carregar logs:', error);
    }
}

// Adiciona linha de log
function appendLogLine(line) {
    const logsContent = document.getElementById('logsContent');
    const logLine = document.createElement('div');
    logLine.className = 'log-line';
    
    // Detecta tipo de log
    if (line.includes('[ERRO]') || line.includes('ERROR')) {
        logLine.classList.add('error');
    } else if (line.includes('[WARN]') || line.includes('WARNING')) {
        logLine.classList.add('warning');
    } else if (line.includes('[INFO]') || line.includes('INFO')) {
        logLine.classList.add('info');
    }
    
    logLine.textContent = line.trim();
    logsContent.appendChild(logLine);
    
    // Scroll para o final
    logsContent.scrollTop = logsContent.scrollHeight;
}

// Adiciona múltiplas linhas de log
function appendLogs(lines) {
    lines.forEach(line => appendLogLine(line));
}

// Limpa logs
function clearLogs() {
    document.getElementById('logsContent').innerHTML = '';
}

// Formata tempo online
function formatUptime(seconds) {
    if (!seconds) return '0s';
    
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    if (hours > 0) {
        return `${hours}h ${minutes}m ${secs}s`;
    } else if (minutes > 0) {
        return `${minutes}m ${secs}s`;
    } else {
        return `${secs}s`;
    }
}

// Carrega informações do servidor (IP público)
async function loadServerInfo() {
    try {
        const response = await fetch('/api/server-info');
        const data = await response.json();
        
        const serverInfo = document.getElementById('serverInfo');
        const publicIpLink = document.getElementById('publicIpLink');
        
        if (data.public_ip && data.public_ip !== 'N/A') {
            serverInfo.style.display = 'flex';
            publicIpLink.textContent = data.public_ip;
            publicIpLink.href = data.public_url;
            publicIpLink.title = `Acessar dashboard em ${data.public_url}`;
        } else {
            // Tenta obter IP público diretamente
            try {
                const ipResponse = await fetch('/api/public-ip');
                const ipData = await ipResponse.json();
                
                if (ipData.success) {
                    serverInfo.style.display = 'flex';
                    publicIpLink.textContent = ipData.ip;
                    publicIpLink.href = ipData.dashboard_url;
                    publicIpLink.title = `Acessar dashboard em ${ipData.dashboard_url}`;
                }
            } catch (error) {
                console.error('Erro ao obter IP público:', error);
            }
        }
    } catch (error) {
        console.error('Erro ao carregar informações do servidor:', error);
    }
}

