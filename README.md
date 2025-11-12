# 🎵 YouTube Live 24/7 - FFmpeg + Railway

## Como usar

1. Faça upload deste projeto no GitHub.
2. Crie uma conta em https://railway.app.
3. Clique em **New Project → Deploy from GitHub Repo**.
4. Escolha este repositório.
5. Adicione uma variável de ambiente:
   - **STREAMKEY** = sua chave do YouTube Live (encontrada no YouTube Studio).
6. Railway vai iniciar e transmitir 24/7 automaticamente.

### Estrutura
- `video.mp4` → vídeo curto em loop (7s)
- `musicas/*.mp3` → suas faixas em MP3
- `start.sh` → faz o streaming contínuo
- `Procfile` → diz à Railway o que rodar

### Dica
- Mantenha bitrate em ~1500kbps (bom para 720p)
- Use músicas 100% livres de direitos
- Se quiser manter ativo sempre, use https://uptimerobot.com para pingar a cada 5 minutos.
