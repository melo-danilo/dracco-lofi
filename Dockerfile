FROM ubuntu:22.04

# Dependências
RUN apt-get update && \
    apt-get install -y ffmpeg python3 python3-pip python3-flask && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    ENABLE_SERVER=1

WORKDIR /app
COPY . /app

RUN chmod +x /app/start_live.sh

CMD ["/app/start_live.sh"]
