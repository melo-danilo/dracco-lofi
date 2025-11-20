# 🎵 Dracco Lo-Fi - Sistema de Streaming 24/7

Sistema completo para transmissão de lives lo-fi 24 horas por dia no YouTube, com dashboard web para gerenciamento e monitoramento.

## ✨ Funcionalidades

- 🎬 **Streaming Automático**: Transmissão contínua de vídeo e áudio lo-fi
- 🔄 **Reinício Automático**: Reinicia automaticamente em horário configurado (24h de duração)
- 📊 **Dashboard Web**: Interface para gerenciar e monitorar as lives
- 🎵 **Múltiplos Canais**: Suporte para múltiplos canais simultâneos
- 📝 **Logs em Tempo Real**: Acompanhamento de logs via WebSocket
- ⚙️ **Configuração Dinâmica**: Ajuste de parâmetros sem reiniciar o container

## 🚀 Início Rápido

### Pré-requisitos

- Docker e Docker Compose
- FFmpeg
- Chave de stream do YouTube

### Instalação

1. Clone o repositório:
```bash
git clone <seu-repositorio>
cd dracco-lofi
```

2. Configure os arquivos de ambiente:
```bash
cp config/example.env config/cozy.env
cp config/example.env config/dracco.env
```

3. Edite os arquivos `.env` com suas configurações:
```bash
# config/cozy.env
YOUTUBE_STREAM_KEY=sua_chave_aqui
RESTART_HOUR=12
```

4. Inicie os serviços:
```bash
docker-compose up -d
```

5. Acesse o dashboard:
```
http://localhost:5000
```

**Credenciais padrão:**
- Usuário: `admin`
- Senha: `admin123`

⚠️ **IMPORTANTE**: Altere as credenciais em produção!

## 📁 Estrutura do Projeto

```
dracco-lofi/
├── config/              # Arquivos de configuração (.env)
│   ├── example.env      # Template de configuração
│   ├── cozy.env         # Configuração do canal cozy
│   └── dracco.env       # Configuração do canal dracco
├── docs/                # Documentação
│   ├── DASHBOARD.md     # Guia do dashboard
│   ├── DEPLOY.md        # Processo de deploy
│   ├── TROUBLESHOOTING.md # Solução de problemas
│   └── RESTART_LOGIC.md # Lógica de reinício
├── scripts/             # Scripts utilitários
│   ├── deploy.sh        # Script de deploy
│   ├── check_dashboard.sh # Diagnóstico do dashboard
│   └── test_restart_logic.sh # Teste da lógica de reinício
├── static/              # Arquivos estáticos do dashboard
│   ├── css/
│   └── js/
├── templates/           # Templates HTML do dashboard
├── musicas_cozy/        # Músicas do canal cozy
├── musicas_dracco/      # Músicas do canal dracco
├── video/               # Vídeos para os canais
├── dashboard.py         # Aplicação Flask do dashboard
├── server.py            # Servidor de healthcheck
├── entrypoint.sh        # Script principal de streaming
├── Dockerfile           # Imagem Docker
├── docker-compose.yml   # Configuração para desenvolvimento
├── docker-stack.yml     # Configuração para produção
└── requirements.txt     # Dependências Python
```

## 📖 Documentação

- [Dashboard](docs/DASHBOARD.md) - Guia completo do dashboard
- [Deploy](docs/DEPLOY.md) - Processo de deploy em produção
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Solução de problemas
- [Lógica de Reinício](docs/RESTART_LOGIC.md) - Como funciona o reinício automático

## ⚙️ Configuração

### Variáveis de Ambiente Principais

```bash
# YouTube
YOUTUBE_STREAM_KEY=sua_chave_de_stream
YOUTUBE_RTMP_BASE=rtmp://a.rtmp.youtube.com/live2

# Canais
CHANNEL_NAME=cozy  # Nome do canal

# Reinício Automático
RESTART_HOUR=12    # Hora para reiniciar (0-23)

# Qualidade de Vídeo
VIDEO_BITRATE=4500k
VIDEO_FPS=30
VIDEO_SCALE=1920:1080

# Qualidade de Áudio
AUDIO_BITRATE=160k
AUDIO_SAMPLE_RATE=44100
```

Veja `config/example.env` para todas as opções disponíveis.

## 🐳 Docker

### Desenvolvimento

```bash
docker-compose up -d
```

### Produção (Docker Swarm)

```bash
docker stack deploy -c docker-stack.yml lofi
```

## 🔧 Desenvolvimento

### Estrutura de Canais

Cada canal precisa de:
- Arquivo de configuração em `config/{canal}.env`
- Diretório de músicas em `musicas_{canal}/`
- Vídeo em `video/{canal}.mp4` ou `video/{canal}_*.mp4`

### Adicionar Novo Canal

1. Crie o arquivo de configuração:
```bash
cp config/example.env config/novo_canal.env
```

2. Adicione o serviço no `docker-compose.yml`:
```yaml
novo_canal:
  build: .
  environment:
    CHANNEL_NAME: novo_canal
  volumes:
    - ./config:/app/config:rw
    - ./musicas_novo_canal:/app/musicas:ro
    - ./video:/app/video:ro
  ports:
    - "8083:8080"
```

3. Adicione também no `docker-stack.yml` para produção.

## 🔒 Segurança

- ⚠️ Altere as credenciais padrão do dashboard
- ⚠️ Use senhas fortes
- ⚠️ Configure `DASHBOARD_SECRET_KEY` com uma chave aleatória
- ⚠️ Considere usar HTTPS em produção
- ⚠️ Restrinja acesso à porta 5000 via firewall

## 🐛 Troubleshooting

Veja a [documentação de troubleshooting](docs/TROUBLESHOOTING.md) para soluções de problemas comuns.

## 📝 Licença

Este projeto é privado e proprietário.

## 🤝 Contribuindo

Este é um projeto privado. Para sugestões ou problemas, abra uma issue no repositório.

## 📞 Suporte

Para problemas ou dúvidas, consulte a documentação em `docs/` ou verifique os logs:

```bash
docker-compose logs -f
```

