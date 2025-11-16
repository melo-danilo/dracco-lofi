FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y ffmpeg curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY server.py /app/server.py

RUN chmod +x /app/entrypoint.sh

CMD ["/app/entrypoint.sh"]
