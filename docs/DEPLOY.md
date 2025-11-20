# Processo de Deploy

## Como Funciona

O projeto usa **Docker Swarm** para deploy em produção. Quando você faz push para a branch `main`, o GitHub Actions executa o deploy automaticamente.

## Fluxo de Deploy

1. **Push para `main`** → GitHub Actions é acionado
2. **GitHub Actions**:
   - Copia arquivos para o servidor (`/root/dracco-stack`)
   - Executa `deploy.sh` no servidor
3. **deploy.sh**:
   - Faz build da imagem Docker: `docker build -t melodanilo/dracco-lofi:latest .`
   - Faz deploy do stack: `docker stack deploy -c docker-stack.yml lofi`

## Arquivos Importantes

### `docker-stack.yml` (Produção)
- Define os serviços que rodam em produção
- Usa a imagem `melodanilo/dracco-lofi:latest`
- **IMPORTANTE**: Qualquer novo serviço precisa ser adicionado aqui!

### `docker-compose.yml` (Desenvolvimento)
- Usado para desenvolvimento local
- Faz build local (`build: .`)
- Não é usado em produção

### `scripts/deploy.sh`
- Script executado no servidor
- Faz build e deploy do stack

## Adicionando Novos Serviços

Se você adicionar um novo serviço (como o dashboard), precisa:

1. ✅ Adicionar no `docker-compose.yml` (para desenvolvimento)
2. ✅ Adicionar no `docker-stack.yml` (para produção) ← **ESSE É O IMPORTANTE!**
3. ✅ Garantir que o Dockerfile copia os arquivos necessários

## Verificar se o Deploy Funcionou

Após o deploy, verifique:

```bash
# No servidor
docker stack services lofi
docker service logs lofi_dashboard
docker service ps lofi_dashboard
```

## Problema: Mudanças não aparecem

Se você fez mudanças no código mas elas não aparecem:

1. **Verifique se fez push para `main`**
   ```bash
   git push origin main
   ```

2. **Verifique se o GitHub Actions executou**
   - Vá em: https://github.com/seu-repo/actions
   - Veja se o workflow "Deploy Stack" executou com sucesso

3. **Verifique se a imagem foi rebuildada**
   ```bash
   # No servidor
   docker images | grep dracco-lofi
   # Veja a data da imagem
   ```

4. **Force rebuild da imagem**
   ```bash
   # No servidor
   docker build --no-cache -t melodanilo/dracco-lofi:latest .
   docker stack deploy -c docker-stack.yml lofi
   ```

