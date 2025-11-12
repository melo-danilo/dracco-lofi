FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV STREAM_KEY=${STREAM_KEY}

# Instala dependências
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Cria virtualenv e instala Flask
RUN python3 -m venv venv
RUN /app/venv/bin/pip install --upgrade pip
RUN /app/venv/bin/pip install flask

# Torna o script executável
RUN chmod +x start_live.sh

EXPOSE 8080

CMD ["bash", "-c", "echo $STREAM_KEY && ./start_live.sh & /app/venv/bin/python3 server.py"]
