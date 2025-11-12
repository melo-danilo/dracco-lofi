FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV STREAM_KEY=$STREAMKEY

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

# Dá permissão de execução ao script
RUN chmod +x /app/start_live.sh

EXPOSE 8080

# Comando final: start_live.sh em background + Flask server
CMD ["bash", "-c", "/app/start_live.sh & /app/venv/bin/python3 server.py"]
