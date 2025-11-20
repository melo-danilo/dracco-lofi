# 📋 Referência Rápida - Comandos Docker Swarm

Guia rápido com os comandos mais usados para gerenciar os serviços.

## 🔍 Ver Status

### Ver todos os serviços
```bash
docker stack services lofi
```

### Ver status detalhado de um serviço
```bash
docker service ps lofi_cozy --no-trunc
docker service ps lofi_dracco --no-trunc
docker service ps lofi_dashboard --no-trunc
```

### Ver status de atualização
```bash
docker service inspect lofi_cozy --format '{{.UpdateStatus}}'
```

## 📝 Ver Logs

### Logs em tempo real
```bash
docker service logs -f lofi_cozy
docker service logs -f lofi_dracco
docker service logs -f lofi_dashboard
```

### Últimas 50 linhas
```bash
docker service logs lofi_cozy --tail 50
```

### Logs de uma task específica
```bash
# Primeiro, pegue o ID da task
TASK_ID=$(docker service ps lofi_cozy --format "{{.ID}}" --no-trunc | head -1)

# Depois veja os logs
docker service logs lofi_cozy --task-id $TASK_ID
```

## 🔄 Reiniciar Serviço

### Forçar reinício (recomendado)
```bash
docker service update --force lofi_cozy
docker service update --force lofi_dracco
docker service update --force lofi_dashboard
```

### Parar e iniciar manualmente
```bash
# Parar
docker service scale lofi_cozy=0

# Iniciar
docker service scale lofi_cozy=1
```

## 🛑 Parar Serviço

```bash
docker service scale lofi_cozy=0
```

## ▶️ Iniciar Serviço

```bash
docker service scale lofi_cozy=1
```

## 🗑️ Remover e Recriar

### Remover um serviço
```bash
docker service rm lofi_cozy
```

### Recriar o stack completo
```bash
docker stack deploy -c docker-stack.yml lofi
```

## 🔧 Resolver Problemas

### Serviço pausado por falha
```bash
# 1. Ver o erro
docker service ps lofi_cozy --no-trunc

# 2. Ver logs
docker service logs lofi_cozy --tail 100

# 3. Forçar atualização
docker service update --force lofi_cozy

# 4. Se não funcionar, remover e recriar
docker service rm lofi_cozy
docker stack deploy -c docker-stack.yml lofi
```

### "Update out of sequence"
```bash
# Aguardar atualizações pendentes
docker service ps lofi_cozy

# Se estiver travado, remover e recriar
docker service rm lofi_cozy
docker stack deploy -c docker-stack.yml lofi
```

## 📊 Monitoramento

### Ver uso de recursos
```bash
docker stats --no-stream | grep lofi
```

### Ver containers rodando
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" | grep lofi
```

### Healthcheck status
```bash
docker service ps lofi_cozy --format "{{.Name}}\t{{.CurrentState}}\t{{.Error}}"
```

## 🚀 Usando o Script de Gerenciamento

O script `scripts/manage_services.sh` facilita o gerenciamento:

```bash
# Ver status
bash scripts/manage_services.sh status

# Ver logs
bash scripts/manage_services.sh logs lofi_cozy

# Reiniciar
bash scripts/manage_services.sh restart lofi_cozy

# Parar
bash scripts/manage_services.sh stop lofi_cozy

# Iniciar
bash scripts/manage_services.sh start lofi_cozy

# Forçar atualização
bash scripts/manage_services.sh update lofi_cozy

# Remover
bash scripts/manage_services.sh remove lofi_cozy

# Deploy completo
bash scripts/manage_services.sh deploy
```

## ⚡ Comandos Mais Usados (Copy & Paste)

### Diagnóstico rápido
```bash
echo "=== Status ==="
docker stack services lofi
echo ""
echo "=== Logs Cozy ==="
docker service logs lofi_cozy --tail 20
echo ""
echo "=== Logs Dracco ==="
docker service logs lofi_dracco --tail 20
echo ""
echo "=== Tasks Cozy ==="
docker service ps lofi_cozy --no-trunc | head -3
```

### Reiniciar tudo
```bash
docker service update --force lofi_cozy
docker service update --force lofi_dracco
docker service update --force lofi_dashboard
```

### Ver tudo de uma vez
```bash
docker stack services lofi && \
docker service ps lofi_cozy --no-trunc | head -2 && \
docker service ps lofi_dracco --no-trunc | head -2 && \
docker service ps lofi_dashboard --no-trunc | head -2
```

