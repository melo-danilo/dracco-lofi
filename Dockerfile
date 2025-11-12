# Dockerfile

FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV STREAMKEY=$STREAMKEY

# Instala dependências essenciais
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copia todos os arquivos do projeto para o container
COPY . /app

# Cria virtualenv e instala Flask
RUN python3 -m venv venv
RUN /app/venv/bin/pip install --upgrade pip
RUN /app/venv/bin/pip install flask

# Expõe porta para o healthcheck do Railway
EXPOSE 8080

# Comando final: roda o start_live.sh em background e mantém Flask ativo para uptime
CMD ["bash", "-c", "/app/start_live.sh & /app/venv/bin/python3 server.py"]
