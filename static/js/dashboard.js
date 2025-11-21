let currentChannel = null;
let socket = null;
let statsInterval = null;
let previewHls = null;

document.addEventListener('DOMContentLoaded', () => {
    loadChannels();
    connectWebSocket();
    loadServerInfo();
    document.getElementById('detailsPanel').style.display = 'none';
});

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

async function loadChannels() {
    try {
        const response = await fetch('/api/channels');
        const data = await response.json();
        const channelsList = document.getElementById('channelsList');
        channelsList.innerHTML = '';

        data.channels.forEach(channel => {
            channelsList.appendChild(createChannelCard(channel));
        });
    } catch (error) {
        console.error('Erro ao carregar canais:', error);
    }
}

function createChannelCard(channel) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.className = 'channel-card';
    btn.onclick = () => showChannelDetails(channel.name);

    const isOnline = channel.status.streaming !== undefined ? channel.status.streaming : channel.status.running;
    const statusClass = isOnline ? 'running' : 'stopped';
    const statusText = isOnline ? 'Online' : 'Offline';
    const activity = channel.status.last_activity || 'Sem atividade recente';

    btn.innerHTML = `
        <div class="channel-name">${channel.name}</div>
        <div class="channel-status">
            <span class="status-indicator ${statusClass}"></span>
            <span>${statusText}</span>
        </div>
        <div class="channel-meta">${activity}</div>
    `;

    return btn;
}

function showChannelDetails(channelName) {
    currentChannel = channelName;
    document.querySelectorAll('.channel-card').forEach(card => {
        card.classList.toggle('active', card.querySelector('.channel-name').textContent === channelName);
    });

    const detailsPanel = document.getElementById('detailsPanel');
    detailsPanel.style.display = 'block';
    document.getElementById('channelDetailTitle').textContent = `Canal: ${channelName}`;
    document.getElementById('channelSubtitle').textContent = `Visão completa da transmissão de ${channelName}`;

    updateConfigFileReference();
    loadChannelStatus();
    loadChannelConfig();
    loadChannelHistory();
    loadChannelLogs();

    if (socket) {
        socket.emit('subscribe_logs', { channel: channelName });
    }

    if (statsInterval) {
        clearInterval(statsInterval);
    }
    statsInterval = setInterval(loadChannelStatus, 5000);
}

function closeDetails() {
    currentChannel = null;
    document.getElementById('detailsPanel').style.display = 'none';
    if (statsInterval) {
        clearInterval(statsInterval);
        statsInterval = null;
    }
    resetPreview();
}

async function loadChannelStatus() {
    if (!currentChannel) return;

    try {
        const response = await fetch(`/api/channel/${currentChannel}/status`);
        const status = await response.json();
        updateStatusUI(status);
        renderPreview(status);
    } catch (error) {
        console.error('Erro ao carregar status:', error);
    }
}

function updateStatusUI(status) {
    const isOnline = status.streaming !== undefined ? status.streaming : status.running;
    const statusLabel = isOnline ? '🟢 Online' : '🔴 Offline';
    const statusDetail = status.running && !isOnline
        ? 'Processo rodando, mas sem envio'
        : (status.last_activity || 'Sem atividade registrada');

    document.getElementById('metricStatus').textContent = statusLabel;
    document.getElementById('metricStatusDetail').textContent = statusDetail;
    document.getElementById('metricUptime').textContent = formatUptime(status.uptime || 0);
    document.getElementById('metricVideo').textContent = status.current_video || 'N/A';
    document.getElementById('metricVideoCount').textContent = status.video_count || 0;
    document.getElementById('metricNextRestart').textContent = status.next_restart || 'N/A';
    document.getElementById('lastConfigSaved').textContent = status.config_last_saved ? new Date(status.config_last_saved).toLocaleString() : 'Ainda não salvo';
    updateControlButtons(status);
}

function renderPreview(status) {
    const previewStatus = document.getElementById('previewStatus');
    const previewHint = document.getElementById('previewHint');
    const previewFallback = document.getElementById('previewFallback');

    if (status.preview_ready && status.preview_url) {
        previewStatus.textContent = 'Preview ativo';
        previewStatus.style.backgroundColor = 'rgba(16, 185, 129, 0.15)';
        previewStatus.style.color = '#4ade80';
        previewHint.textContent = 'Preview acompanha exatamente o stream enviado ao YouTube.';
        previewFallback.style.display = 'none';
        attachPreviewStream(status.preview_url);
    } else {
        previewStatus.textContent = 'Preview indisponível';
        previewStatus.style.backgroundColor = 'rgba(248, 113, 113, 0.15)';
        previewStatus.style.color = '#f87171';
        previewHint.textContent = 'O preview ficará disponível assim que o FFmpeg iniciar.';
        previewFallback.style.display = 'flex';
        previewFallback.textContent = 'Preview ainda não gerado';
        resetPreview();
    }
}

function updateControlButtons(status) {
    const isOnline = status.streaming !== undefined ? status.streaming : status.running;
    document.getElementById('btnStart').disabled = isOnline;
    document.getElementById('btnStop').disabled = !isOnline;
    document.getElementById('btnRestart').disabled = !isOnline;
}

function attachPreviewStream(url) {
    const video = document.getElementById('livePreviewVideo');
    if (previewHls) {
        previewHls.destroy();
        previewHls = null;
    }

    if (window.Hls && Hls.isSupported()) {
        previewHls = new Hls();
        previewHls.loadSource(url);
        previewHls.attachMedia(video);
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
        video.src = url;
    } else {
        document.getElementById('previewFallback').textContent = 'Seu navegador não suporta HLS automaticamente.';
        document.getElementById('previewFallback').style.display = 'flex';
        return;
    }
    video.play().catch(() => {});
}

function resetPreview() {
    const video = document.getElementById('livePreviewVideo');
    if (previewHls) {
        previewHls.destroy();
        previewHls = null;
    }
    video.pause();
    video.removeAttribute('src');
    video.load();
}

function formatUptime(seconds) {
    if (!seconds) return '0s';
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    if (hours > 0) {
        return `${hours}h ${minutes}m ${secs}s`;
    } else if (minutes > 0) {
        return `${minutes}m ${secs}s`;
    }
    return `${secs}s`;
}

async function loadChannelConfig() {
    if (!currentChannel) return;

    try {
        const response = await fetch(`/api/channel/${currentChannel}/config`);
        const data = await response.json();
        populateConfigForm(data.config);
        if (data.last_saved) {
            document.getElementById('lastConfigSaved').textContent = new Date(data.last_saved).toLocaleString();
        }
    } catch (error) {
        console.error('Erro ao carregar configuração:', error);
    }
}

function populateConfigForm(config) {
    document.getElementById('restartHour').value = config.RESTART_HOUR || '12';
    document.getElementById('videoBitrate').value = config.VIDEO_BITRATE || '4500k';
    document.getElementById('audioBitrate').value = config.AUDIO_BITRATE || '160k';
    document.getElementById('videoFps').value = config.VIDEO_FPS || '30';
    document.getElementById('videoScale').value = config.VIDEO_SCALE || '1920:1080';
}

document.getElementById('configForm').addEventListener('submit', async (event) => {
    event.preventDefault();
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
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ updates })
        });
        const data = await response.json();
        if (data.success) {
            document.getElementById('configSaveMessage').textContent = 'Configuração salva com sucesso.';
            document.getElementById('lastConfigSaved').textContent = new Date(data.last_saved).toLocaleString();
            loadChannelHistory();
        } else {
            document.getElementById('configSaveMessage').textContent = data.error || 'Erro ao salvar configuração.';
        }
    } catch (error) {
        console.error('Erro ao salvar configuração:', error);
        document.getElementById('configSaveMessage').textContent = 'Erro ao salvar configuração.';
    }
});

async function loadChannelHistory() {
    if (!currentChannel) return;

    try {
        const response = await fetch(`/api/channel/${currentChannel}/config/history`);
        const data = await response.json();
        renderHistoryList(data.history || []);
    } catch (error) {
        console.error('Erro ao carregar histórico de configuração:', error);
    }
}

function renderHistoryList(history) {
    const historyContainer = document.getElementById('configHistoryList');
    historyContainer.innerHTML = '';
    if (!history.length) {
        historyContainer.innerHTML = '<li>Nenhuma atualização registrada.</li>';
        return;
    }

    history.forEach(entry => {
        const item = document.createElement('li');
        const date = entry.timestamp ? new Date(entry.timestamp).toLocaleString() : 'Data indisponível';
        const keys = Object.keys(entry.updates || {});
        item.innerHTML = `
            <strong>${date}</strong>
            <span>${keys.length ? keys.join(', ') : 'Sem alterações registradas'}</span>
        `;
        historyContainer.appendChild(item);
    });
}

async function loadChannelLogs() {
    if (!currentChannel) return;

    try {
        const response = await fetch(`/api/channel/${currentChannel}/logs?lines=100`);
        const data = await response.json();
        const logsContainer = document.getElementById('logsContent');
        logsContainer.innerHTML = '';
        appendLogs(data.logs || []);
    } catch (error) {
        console.error('Erro ao carregar logs:', error);
    }
}

function appendLogLine(line) {
    const logsContent = document.getElementById('logsContent');
    const logLine = document.createElement('div');
    logLine.className = 'log-line';
    if (line.includes('[ERRO]') || line.includes('ERROR')) {
        logLine.classList.add('error');
    } else if (line.includes('[WARN]') || line.includes('WARNING')) {
        logLine.classList.add('warning');
    } else if (line.includes('[INFO]') || line.includes('INFO')) {
        logLine.classList.add('info');
    }
    logLine.textContent = line.trim();
    logsContent.appendChild(logLine);
    logsContent.scrollTop = logsContent.scrollHeight;
}

function appendLogs(lines) {
    lines.forEach(line => appendLogLine(line));
}

function clearLogs() {
    document.getElementById('logsContent').innerHTML = '';
}

async function stopChannel() {
    if (!currentChannel) return;
    if (!confirm(`Deseja encerrar a live ${currentChannel}?`)) return;

    try {
        const response = await fetch(`/api/channel/${currentChannel}/stop`, { method: 'POST' });
        const data = await response.json();
        if (data.success) {
            setControlStatus('Comando de encerramento enviado!');
            setTimeout(loadChannelStatus, 2000);
        } else {
            setControlStatus('Erro ao encerrar live.', 'error');
        }
    } catch (error) {
        console.error('Erro ao encerrar canal:', error);
        setControlStatus('Erro ao encerrar live.', 'error');
    }
}

async function startChannel() {
    if (!currentChannel) return;
    try {
        setControlStatus('Acionando live...');
        const response = await fetch(`/api/channel/${currentChannel}/start`, { method: 'POST' });
        const data = await response.json();
        if (data.success) {
            setControlStatus('Live será iniciada em instantes.');
            setTimeout(loadChannelStatus, 3000);
        } else {
            setControlStatus('Erro ao iniciar live.', 'error');
        }
    } catch (error) {
        console.error('Erro ao iniciar canal:', error);
        setControlStatus('Erro ao iniciar live.', 'error');
    }
}

async function restartChannel() {
    if (!currentChannel) return;
    if (!confirm(`Deseja reiniciar a live ${currentChannel}? O stream será encerrado e iniciado novamente.`)) return;

    try {
        setControlStatus('Reinicializando stream...');
        const response = await fetch(`/api/channel/${currentChannel}/restart`, { method: 'POST' });
        const data = await response.json();
        if (data.success) {
            setControlStatus('Live reiniciada. Aguardando nova transmissão...');
            setTimeout(loadChannelStatus, 5000);
        } else {
            setControlStatus('Erro ao reiniciar live.', 'error');
        }
    } catch (error) {
        console.error('Erro ao reiniciar canal:', error);
        setControlStatus('Erro ao reiniciar live.', 'error');
    }
}

function setControlStatus(message, tone = 'info') {
    const controlStatus = document.getElementById('controlStatus');
    controlStatus.textContent = message;
    controlStatus.style.color = tone === 'error' ? '#ef4444' : '#1f2937';
}

function updateConfigFileReference() {
    const ref = document.getElementById('configFileReference');
    if (currentChannel) {
        ref.textContent = `config/${currentChannel}.env`;
    }
}

function loadServerInfo() {
    fetch('/api/server-info')
        .then(res => res.json())
        .then(data => {
            const serverInfo = document.getElementById('serverInfo');
            const publicIpLink = document.getElementById('publicIpLink');
            if (data.public_ip && data.public_ip !== 'N/A') {
                serverInfo.style.display = 'flex';
                publicIpLink.textContent = data.public_ip;
                publicIpLink.href = data.public_url;
            }
        })
        .catch(error => console.error('Erro ao carregar IP:', error));
}

