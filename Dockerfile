FROM python:3.11-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV ENABLE_SERVER=1

RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg ca-certificates python3-flask curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

RUN chmod +x /app/start_live.sh

HEALTHCHECK --interval=10s --timeout=3s --start-period=15s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/ || exit 1

CMD ["/app/start_live.sh"]
