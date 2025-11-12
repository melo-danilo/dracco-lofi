# 🎵 YouTube Live 24/7 – FFmpeg + Railway

Projeto pronto para transmitir uma live contínua (24/7) no YouTube usando FFmpeg.
Funciona em containers Docker e foi pensado para deploy direto no Railway.

---

## 📦 Estrutura

- `video.mp4` → vídeo exibido em loop durante a live (coloque sua arte/loop aqui).
- `musicas/` → arquivos `.mp3` que formarão a playlist (copie suas faixas para esta pasta).
- `start_live.sh` → script de entrada: prepara a playlist, sobe o FFmpeg e inicia um servidor HTTP de health-check.
- `server.py` → microservidor Flask (porta 8080) usado para health-checks pela Railway.
- `Dockerfile` → imagem baseada em Ubuntu 22.04 com FFmpeg + Python + Flask.

---

## 🚀 Deploy no Railway

1. Suba este repositório no GitHub.
2. Na Railway, clique em **New Project → Deploy from GitHub Repo** e selecione o repo.
3. Quando a Railway detectar o `Dockerfile`, basta confirmar o deploy.
4. Nas variáveis de ambiente, configure **UMA** das opções abaixo:
   - `STREAM_URL`: URL completa RTMP (ex.: `rtmp://a.rtmp.youtube.com/live2/SEU_TOKEN`)
   - ou `YOUTUBE_STREAM_KEY` / `STREAM_KEY` / `STREAMKEY`: apenas a chave; a URL base padrão (`rtmp://a.rtmp.youtube.com/live2`) será montada automaticamente.
5. Opcional: ajuste qualidade de vídeo/áudio usando as variáveis (ver seção “Ajustes finos”).
6. Faça deploy. O Railway vai executar `/app/start_live.sh`, que mantém o FFmpeg rodando continuamente.

> **Dica:** se quiser garantir que a Railway não pare o container por inatividade, configure um monitor no [UptimeRobot](https://uptimerobot.com) para pingar seu endpoint a cada poucos minutos.

---

## ⚙️ Ajustes finos

Todas as variáveis abaixo são opcionais (valores padrão entre parênteses):

- `MP3_DIR` → diretório das músicas dentro do container (`/app/musicas`)
- `VIDEO_FILE` → vídeo exibido na live (`/app/video.mp4`)
- `VIDEO_BITRATE` → bitrate alvo do vídeo (`4000k`)
- `VIDEO_MAXRATE` → bitrate máximo do vídeo (`4500k`)
- `VIDEO_BUFSIZE` → buffer do vídeo (`8000k`)
- `GOP_SIZE` → intervalo de keyframe, em frames (`120`)
- `AUDIO_BITRATE` → bitrate do áudio (`128k`)
- `AUDIO_SAMPLE_RATE` → sample rate do áudio (`44100`)
- `ENABLE_SERVER` → liga/desliga o servidor HTTP de health-check (`1`)

---

## ✅ Requisitos dos arquivos

- Coloque apenas `.mp3` com o mesmo codec e sample rate para evitar problemas ao concatenar.
- O script falha com uma mensagem clara caso não encontre o diretório de músicas, nenhum MP3 ou o vídeo principal.

---

## 🧪 Testes locais

```bash
# Build da imagem
docker build -t youtube-live .

# Execução local (exemplo)
docker run --rm \
  -e STREAM_URL="rtmp://a.rtmp.youtube.com/live2/SEU_TOKEN" \
  youtube-live
```

> Ajuste volumes (`-v`) se quiser montar suas próprias músicas/vídeo durante o teste.

---

## ℹ️ Notas finais

- Use músicas livres de direitos autorais para evitar derrubarem a transmissão.
- A transmissão é reiniciada automaticamente caso o FFmpeg pare.
- Atualize `video.mp4` e as músicas sempre que quiser mudar o conteúdo da live.
