# Estrutura do Projeto

## Visão Geral

```
dracco-lofi/
├── config/              # Configurações dos canais
├── docs/                # Documentação
├── scripts/             # Scripts utilitários
├── static/              # Arquivos estáticos (CSS/JS)
├── templates/           # Templates HTML
├── musicas_cozy/        # Músicas do canal cozy
├── musicas_dracco/      # Músicas do canal dracco
├── video/               # Vídeos para os canais
└── thumb/               # Thumbnails
```

## Diretórios Principais

### `config/`
Arquivos de configuração `.env` para cada canal.

- `example.env` - Template de configuração
- `cozy.env` - Configuração do canal cozy
- `dracco.env` - Configuração do canal dracco

### `docs/`
Documentação completa do projeto.

- `DASHBOARD.md` - Guia do dashboard
- `DEPLOY.md` - Processo de deploy
- `TROUBLESHOOTING.md` - Solução de problemas
- `RESTART_LOGIC.md` - Lógica de reinício automático
- `STRUCTURE.md` - Este arquivo

### `scripts/`
Scripts utilitários e de deploy.

- `deploy.sh` - Script de deploy em produção
- `check_dashboard.sh` - Diagnóstico do dashboard
- `test_restart_logic.sh` - Teste da lógica de reinício

### `static/`
Arquivos estáticos do dashboard web.

- `css/dashboard.css` - Estilos do dashboard
- `js/dashboard.js` - JavaScript do dashboard

### `templates/`
Templates HTML do dashboard.

- `dashboard.html` - Página principal do dashboard
- `login.html` - Página de login

### `musicas_{canal}/`
Diretórios com músicas MP3 para cada canal.

### `video/`
Vídeos MP4 para os canais. O sistema procura por:
- `{canal}_*.mp4` (padrão preferido)
- `{canal}.mp4` (fallback)

## Arquivos Principais

### `dashboard.py`
Aplicação Flask do dashboard web. Gerencia:
- Autenticação
- Controle dos canais
- Configuração
- Logs em tempo real

### `entrypoint.sh`
Script principal que executa o streaming. Responsável por:
- Carregar configurações
- Gerar playlist de músicas
- Iniciar FFmpeg
- Gerenciar reinício automático

### `server.py`
Servidor HTTP simples para healthcheck dos containers.

### `Dockerfile`
Define a imagem Docker com todas as dependências.

### `docker-compose.yml`
Configuração para desenvolvimento local.

### `docker-stack.yml`
Configuração para produção (Docker Swarm).

## Fluxo de Dados

1. **Configuração**: Arquivos `.env` em `config/`
2. **Streaming**: `entrypoint.sh` lê config e inicia FFmpeg
3. **Monitoramento**: `dashboard.py` lê logs e stats
4. **Controle**: Dashboard cria arquivos em `control/`
5. **Estatísticas**: `entrypoint.sh` escreve em `stats/`

## Diretórios de Runtime

Estes diretórios são criados em runtime e não devem ser commitados:

- `logs/` - Logs de cada canal
- `stats/` - Estatísticas em JSON
- `control/` - Arquivos de controle (stop, restart, reload)

