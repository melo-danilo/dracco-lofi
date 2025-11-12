# Dockerfile
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV STREAMKEY=$STREAMKEY

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Define diretório de trabalho
WORKDIR /app

# Copia os arquivos da aplicação
COPY . /app

# Cria e ativa virtualenv
RUN python3 -m venv venv
RUN /app/venv/bin/pip install --upgrade pip
RUN /app/venv/bin/pip install flask

# Expõe porta para healthcheck
EXPOSE 8080

# Permissão para o start_live.sh
RUN chmod +x /app/start_live.sh

# Comando final: roda o live e o server Flask em paralelo
CMD ["bash", "-c", "/app/start_live.sh & /app/venv/bin/python3 server.py"]
