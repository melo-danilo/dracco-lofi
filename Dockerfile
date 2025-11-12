FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-venv \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Cria e ativa virtualenv, instala Flask
RUN python3 -m venv venv
RUN /app/venv/bin/pip install --upgrade pip
RUN /app/venv/bin/pip install flask

# Expõe porta do Flask para healthcheck
EXPOSE 8080

# Comando final: inicia a live e o servidor Flask
CMD ["bash", "-c", "./start_live.sh & /app/venv/bin/python3 server.py"]
