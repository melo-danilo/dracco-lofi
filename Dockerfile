# Base image com ffmpeg e python
FROM ubuntu:22.04

# Instala dependências
RUN apt-get update && \
    apt-get install -y ffmpeg python3 python3-pip tini && \
    rm -rf /var/lib/apt/lists/*

# Define diretório de trabalho
WORKDIR /app

# Copia todos os arquivos do projeto
COPY . /app

# Dá permissão de execução ao script
RUN chmod +x main.sh

# Expõe porta para ping
EXPOSE 8000

# Usa tini como init para gerenciar sinais corretamente
ENTRYPOINT ["/usr/bin/tini", "--"]

# Comando principal em JSON (forma recomendada)
CMD ["bash", "-c", "./main.sh & python3 server.py"]
