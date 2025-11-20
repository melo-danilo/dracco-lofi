# 📚 Índice da Documentação

Bem-vindo à documentação do Dracco Lo-Fi. Escolha o tópico que deseja consultar:

## 🚀 Início Rápido

- **[README.md](../README.md)** - Visão geral do projeto e início rápido

## 📖 Documentação

### Dashboard
- **[DASHBOARD.md](DASHBOARD.md)** - Guia completo do dashboard web
  - Funcionalidades
  - Como usar
  - Configuração
  - Segurança

### Deploy
- **[DEPLOY.md](DEPLOY.md)** - Processo de deploy em produção
  - Fluxo de deploy
  - Docker Swarm
  - GitHub Actions
  - Adicionar novos serviços

### Troubleshooting
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Solução de problemas
  - Dashboard não carrega
  - Logs não aparecem
  - Configurações não aplicadas
  - Problemas comuns

### Funcionalidades
- **[RESTART_LOGIC.md](RESTART_LOGIC.md)** - Lógica de reinício automático
  - Como funciona
  - Configuração
  - Problemas corrigidos
  - Testes

### Estrutura
- **[STRUCTURE.md](STRUCTURE.md)** - Estrutura do projeto
  - Diretórios
  - Arquivos principais
  - Fluxo de dados

## 🔧 Scripts

Scripts utilitários estão em `scripts/`:

- `deploy.sh` - Script de deploy em produção
- `check_dashboard.sh` - Diagnóstico do dashboard
- `test_restart_logic.sh` - Teste da lógica de reinício

## 📝 Configuração

Arquivos de configuração estão em `config/`:

- `example.env` - Template de configuração
- `{canal}.env` - Configuração de cada canal

## 🆘 Precisa de Ajuda?

1. Consulte a [documentação de troubleshooting](TROUBLESHOOTING.md)
2. Verifique os logs: `docker-compose logs -f`
3. Execute o script de diagnóstico: `bash scripts/check_dashboard.sh`

