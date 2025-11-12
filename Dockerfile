FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive

# Dependências do sistema (imagem menor e build mais rápido)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg ca-certificates python3-flask curl && \
    rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    ENABLE_SERVER=1

WORKDIR /app
COPY . /app

RUN chmod +x /app/start_live.sh

CMD ["/app/start_live.sh"]
