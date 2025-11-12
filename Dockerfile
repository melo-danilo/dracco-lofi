FROM ubuntu:22.04

# Dependências
RUN apt-get update && \
    apt-get install -y ffmpeg python3 python3-pip && \
    apt-get clean

WORKDIR /app
COPY . /app

RUN chmod +x /app/start_live.sh

CMD ["/app/start_live.sh"]
