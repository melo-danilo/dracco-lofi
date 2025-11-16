FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Instala dependências do sistema (ffmpeg e curl)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala Flask (usado pelo healthcheck)
RUN apt-get update && apt-get install -y --no-install-recommends python3-pip && \
    pip3 install --no-cache-dir flask && \
    rm -rf /var/lib/apt/lists/*

# Copia o código
COPY . /app

# Permissões
RUN chmod +x /app/start_live.sh

# Healthcheck interno (verifica endpoint HTTP)
HEALTHCHECK --interval=20s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/health || exit 1

CMD ["/app/start_live.sh"]
