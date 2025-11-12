#!/bin/bash
# start_live.sh
# Concatena todas as músicas e mantém a live rodando sem travamentos

# Caminho da pasta de músicas
MUSIC_FOLDER="musicas_fixed"
CONCAT_FILE="musicas_concat.mp3"

# Cria arquivo de concat se não existir ou se for necessário atualizar
echo "Preparando arquivo de músicas concatenadas..."
rm -f "$CONCAT_FILE"

# Cria lista temporária para concat
LIST_FILE=$(mktemp)
for f in "$MUSIC_FOLDER"/*.mp3; do
    # Escape de caracteres especiais
    echo "file '$PWD/$f'" >> "$LIST_FILE"
done

# Concatena todos os MP3 em um só
ffmpeg -y -f concat -safe 0 -i "$LIST_FILE" -c copy "$CONCAT_FILE"
rm "$LIST_FILE"

echo "Arquivo concatenado pronto: $CONCAT_FILE"

# Loop infinito para a live
while true; do
    echo "Iniciando live..."
    ffmpeg -re -stream_loop -1 -i "$CONCAT_FILE" -i video.mp4 \
        -map 1:v:0 -map 0:a:0 \
        -vf "scale=1920:1080" \
        -c:v libx264 -preset veryfast -b:v 6000k -maxrate 6000k -bufsize 12000k \
        -c:a aac -b:a 128k -f flv "rtmp://a.rtmp.youtube.com/live2/$STREAMKEY"
    
    echo "FFmpeg travou ou finalizou, reiniciando em 5s..."
    sleep 5
done
