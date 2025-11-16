#!/usr/bin/env bash
set -euo pipefail

APPDIR="${APPDIR:-/root/dracco-lofi}"
STACK_FILE="${STACK_FILE:-docker-stack.yml}"
STACK_NAME="${STACK_NAME:-livestreams}"

echo "Deploy script - appdir=$APPDIR stack=$STACK_FILE"

cd "$APPDIR"

# build cozy image
echo "Building image: dracco-lofi:cozy"
docker build --pull -t dracco-lofi:cozy --build-arg CHANNEL=cozy .

# build dracco image
echo "Building image: dracco-lofi:dracco"
docker build --pull -t dracco-lofi:dracco --build-arg CHANNEL=dracco .

# deploy stack (Swarm)
echo "Deploying stack $STACK_NAME with $STACK_FILE"
docker stack deploy -c "$STACK_FILE" "$STACK_NAME"

echo "Deploy iniciado. Verificando serviços..."
sleep 5
docker stack services "$STACK_NAME"
echo "Done."
