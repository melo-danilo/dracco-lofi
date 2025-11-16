#!/bin/bash

set -e

# Evita o erro 'dubious ownership'
git config --global --add safe.directory /root/dracco-stack

docker build -t melodanilo/dracco-lofi:latest .

docker stack deploy -c docker-stack.yml lofi

echo "Deploy concluído!"
