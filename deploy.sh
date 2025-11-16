#!/bin/bash
set -e

cd /root/dracco-stack

git pull

docker build -t melodanilo/dracco-lofi:latest .

docker stack deploy --with-registry-auth -c docker-stack.yml lofi
