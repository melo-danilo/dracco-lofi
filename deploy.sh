#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="${STACK_DIR:-/root/dracco-stack}"
STACK_FILE="${STACK_FILE:-docker-stack.yml}"
IMAGE="${IMAGE:-${DOCKERHUB_USER:-melodanilo}/dracco-lofi:latest}"
STACK_NAME="${STACK_NAME:-lofi}"

echo "Pulling image ${IMAGE}..."
docker pull "${IMAGE}"

echo "Deploying stack ${STACK_NAME}..."
cd "${STACK_DIR}"
docker stack deploy -c "${STACK_FILE}" "${STACK_NAME}"

echo "Done. Use 'docker service logs ${STACK_NAME}_cozy -f' to tail logs."
