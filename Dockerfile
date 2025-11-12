# Base image com ffmpeg e python
FROM ubuntu:22.04

# Instala dependências
RUN apt-get update && \
    apt-get install -y ffmpeg python3 python3-pip

# Copia os arquivos do projeto
WORKDIR /app
COPY . /app

# Dá permissão de execução ao script
RUN chmod +x main.sh

# Expõe porta para ping
EXPOSE 8000

# Comando para rodar FFmpeg + servidor ping
CMD bash -c "./main.sh & python3 server.py"
