FROM ubuntu:24.04

# Variáveis de ambiente
ENV DEBIAN_FRONTEND=noninteractive
ENV STREAM_KEY=$STREAM_KEY

# Instala dependências
RUN apt-get update && apt-get install -y \
    ffmpeg \
    python3 \
    python3-pip \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copia arquivos
WORKDIR /app
COPY . /app

# Instala Flask
RUN pip3 install flask

# Expõe porta para o healthcheck
EXPOSE 8080

# Comando para iniciar ffmpeg em loop e o server.py
CMD ["bash", "-c", "./start_live.sh & python3 server.py"]
