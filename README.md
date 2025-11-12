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
- `VIDEO_BITRATE` → bitrate alvo do vídeo (`4500k`)
- `VIDEO_MAXRATE` → bitrate máximo do vídeo (`5500k`)
- `VIDEO_BUFSIZE` → buffer do vídeo (`8000k`)
- `VIDEO_SCALE` → resolução de saída no formato `LARGURA:ALTURA` (`1920:1080`)
- `VIDEO_FPS` → frames por segundo de saída (`30`)
- `GOP_SIZE` → intervalo de keyframe, em frames (`60`)
- `VIDEO_PRESET` → preset do x264 (`superfast`)
- `VIDEO_FILTER_EXTRA` → filtros FFmpeg adicionais (ex.: `fps=60`)
- `FORCE_SQUARE_PIXELS` → aplica `setsar=1` para evitar bordas pretas (`1`)
- `AUDIO_BITRATE` → bitrate do áudio (`160k`)
- `AUDIO_SAMPLE_RATE` → sample rate do áudio (`44100`)
- `ENFORCE_CBR` → quando `1`, adiciona flags `-muxdelay 0 -muxpreload 0.5` para fluxo RTMP mais constante (`0`)
- `VIDEO_SOURCE_URL` → URL para baixar o `video.mp4` no startup (opcional)
- `VIDEO_DOWNLOAD_RETRIES` → número de tentativas ao baixar o vídeo (`3`)
- `VIDEO_DOWNLOAD_TIMEOUT` → tempo máximo (s) por download (`300`)
- `CHANNEL_NAME` → nome/identificador do canal para reutilizar configs (`""`)
- `CHANNEL_CONFIG_FILE` → caminho do arquivo `.env` a ser carregado (padrão: `config/<CHANNEL_NAME>.env`)
- `STREAM_KEY_FILE` → caminho para um arquivo contendo a chave da live (remove quebras de linha)
- `YOUTUBE_RTMP_BASE` → URL base do servidor RTMP do YouTube (padrão: `rtmp://a.rtmp.youtube.com/live2`). Pode ser `rtmp://a.rtmp.youtube.com/live2`, `rtmp://b.rtmp.youtube.com/live2`, `rtmp://x.rtmp.youtube.com/live2`, etc.
- `FFMPEG_THREADS` → número de threads usados pelo encoder (`2`)
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
  -e VIDEO_SCALE=1920:1080 \
  -e VIDEO_FPS=30 \
  -e VIDEO_PRESET=superfast \
  -e VIDEO_BITRATE=4500k \
  -e VIDEO_MAXRATE=5500k \
  -e VIDEO_BUFSIZE=8000k \
  -e AUDIO_SAMPLE_RATE=44100 \
  -e FFMPEG_THREADS=2 \
  youtube-live
```

> Ajuste volumes (`-v`) se quiser montar suas próprias músicas/vídeo durante o teste.

---

## ℹ️ Notas finais

- Use músicas livres de direitos autorais para evitar derrubarem a transmissão.
- A transmissão é reiniciada automaticamente caso o FFmpeg pare.
- Atualize `video.mp4` e as músicas sempre que quiser mudar o conteúdo da live.
- Para 1080p60 (requer mais CPU/RAM), configure `VIDEO_FPS=60` e ajuste `VIDEO_BITRATE`/`VIDEO_MAXRATE` (ex.: `VIDEO_BITRATE=8500k`, `VIDEO_MAXRATE=9500k`) e considere `FFMPEG_THREADS=4`.

---

## 💡 Dica para plano de 1 GB no Railway

Valores recomendados para manter 1080p estável consumindo menos memória:

- `VIDEO_PRESET=superfast`
- `VIDEO_BITRATE=4500k`
- `VIDEO_MAXRATE=5500k`
- `VIDEO_BUFSIZE=8000k`
- `VIDEO_FPS=30` (ou `24` se ainda estiver pesado)
- `AUDIO_SAMPLE_RATE=44100`
- `FFMPEG_THREADS=2`
- `ENABLE_SERVER=0` (se não precisar do health-check HTTP)

Monitore os logs: se o ffmpeg for “Killed”, reduza FPS/bitrate ou aumente o preset (ex.: `ultrafast`).

---

## 🎯 Mantendo o mesmo código para múltiplos canais

Para replicar o projeto em vários serviços/canais apenas trocando variáveis:

- `YOUTUBE_STREAM_KEY` ou `STREAM_URL`: configure a chave/canal específico em cada deploy (ou use `STREAM_KEY_FILE` apontando para um arquivo com a chave).
- `VIDEO_FILE`: aponte para um arquivo diferente já incluído na imagem ou montado por volume.
- `VIDEO_SOURCE_URL`: defina uma URL (S3, GitHub Releases, CDN etc.) e o container baixará o vídeo ao iniciar — útil quando cada canal precisa de um vídeo diferente sem rebuild.
- `MP3_DIR`: mantenha a mesma biblioteca de músicas ou monte outra pasta por serviço, se necessário.

Assim você reutiliza o mesmo repositório, alterando apenas as variáveis no painel da Railway/Render.

> Dica: use o modelo `config/example.env`. Copie para `config/<nome-do-canal>.env`, ajuste as variáveis (ex.: `VIDEO_FILE=/app/videos/canal1.mp4`, `VIDEO_BITRATE=3500k`) e defina `CHANNEL_NAME=canal1` no serviço correspondente para que o script carregue tudo automaticamente.
