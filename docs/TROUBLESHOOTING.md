# Troubleshooting

## Dashboard não carrega

### Diagnóstico Rápido

Execute estes comandos no seu servidor:

```bash
# 1. Verificar se o container está rodando
docker-compose ps

# 2. Ver logs do dashboard
docker-compose logs dashboard

# 3. Verificar se está respondendo internamente
docker-compose exec dashboard curl http://localhost:5000
```

### Soluções Comuns

#### Container não está rodando
```bash
docker-compose up -d dashboard
docker-compose logs -f dashboard
```

#### Reconstruir o container
```bash
docker-compose down dashboard
docker-compose build dashboard
docker-compose up -d dashboard
```

#### Porta 5000 já em uso
```bash
# Ver o que está usando a porta
sudo lsof -i :5000
# ou
sudo netstat -tulpn | grep 5000
```

#### Firewall bloqueando
```bash
# Ubuntu/Debian
sudo ufw allow 5000/tcp
sudo ufw reload

# CentOS/RHEL
sudo firewall-cmd --add-port=5000/tcp --permanent
sudo firewall-cmd --reload
```

#### Erro de módulo não encontrado
```bash
docker-compose exec dashboard pip install -r /app/requirements.txt
docker-compose restart dashboard
```

### Checklist Completo

- [ ] Container `dashboard` está com status `Up`?
- [ ] Logs mostram algum erro?
- [ ] Dashboard responde internamente (curl dentro do container)?
- [ ] Porta 5000 está aberta no firewall?
- [ ] Nenhum outro processo está usando a porta 5000?
- [ ] Arquivos `templates/` e `static/` existem no container?

### O que verificar nos logs

Procure por estas mensagens de erro:

- `ModuleNotFoundError` → Dependências não instaladas
- `Address already in use` → Porta ocupada
- `Permission denied` → Problema de permissão
- `No such file or directory` → Arquivos faltando

## Logs não aparecem

- Verifique se o diretório `/app/logs` existe e tem permissões
- Verifique se o canal está gerando logs

## Configurações não são aplicadas

- As configurações são salvas, mas podem precisar de reinício manual
- Use o botão "Reiniciar Live" para aplicar mudanças

