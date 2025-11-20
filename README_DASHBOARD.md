# Dashboard de Gerenciamento de Lives Lo-Fi

Dashboard web para gerenciar e monitorar as lives lo-fi.

## Funcionalidades

- ✅ **Autenticação**: Login e senha para acesso seguro
- ✅ **Gerenciamento de Lives**: Encerrar e reiniciar lives manualmente
- ✅ **Configuração**: Ajustar parâmetros das lives (hora de reinício, bitrates, FPS, etc.)
- ✅ **Estatísticas**: Visualizar status, tempo online, vídeo atual
- ✅ **Logs em Tempo Real**: Acompanhar logs das lives via WebSocket

## Como Usar

### 1. Configuração Inicial

As credenciais padrão são:
- **Usuário**: `admin`
- **Senha**: `admin123`

Para alterar, defina as variáveis de ambiente no `docker-compose.yml`:
```yaml
environment:
  DASHBOARD_USER: seu_usuario
  DASHBOARD_PASSWORD: sua_senha_segura
  DASHBOARD_SECRET_KEY: sua_chave_secreta_aleatoria
```

### 2. Iniciar o Dashboard

```bash
docker-compose up -d
```

O dashboard estará disponível em: **http://localhost:5000**

### 3. Funcionalidades do Dashboard

#### Status
- Visualiza status atual da live (Online/Offline)
- Tempo online desde o último reinício
- Vídeo atual sendo transmitido
- Próximo reinício agendado

#### Configuração
- **Hora de Reinício**: Define quando a live será reiniciada (0-23)
- **Bitrate de Vídeo**: Qualidade do vídeo (ex: 4500k)
- **Bitrate de Áudio**: Qualidade do áudio (ex: 160k)
- **FPS**: Frames por segundo (24-60)
- **Resolução**: Resolução do vídeo (ex: 1920:1080)

#### Logs
- Visualiza logs em tempo real
- Filtros automáticos por tipo (INFO, WARN, ERRO)
- Atualização automática via WebSocket

### 4. Controles

- **Encerrar Live**: Para a transmissão atual
- **Reiniciar Live**: Encerra e reinicia a live imediatamente
- **Salvar Configuração**: Aplica novas configurações (requer reinício)

## Estrutura de Arquivos

```
/app
├── logs/          # Logs de cada canal
├── stats/         # Estatísticas em JSON
├── control/       # Arquivos de controle (stop, restart, reload)
└── config/        # Arquivos de configuração (.env)
```

## Segurança

⚠️ **IMPORTANTE**: Altere as credenciais padrão em produção!

Recomendações:
- Use senhas fortes
- Configure `DASHBOARD_SECRET_KEY` com uma chave aleatória
- Considere usar HTTPS em produção
- Restrinja acesso à porta 5000 via firewall

## Troubleshooting

### Dashboard não carrega
- Verifique se o container está rodando: `docker-compose ps`
- Verifique os logs: `docker-compose logs dashboard`

### Logs não aparecem
- Verifique se o diretório `/app/logs` existe e tem permissões
- Verifique se o canal está gerando logs

### Configurações não são aplicadas
- As configurações são salvas, mas podem precisar de reinício manual
- Use o botão "Reiniciar Live" para aplicar mudanças

