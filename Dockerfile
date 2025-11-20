FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y ffmpeg curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY entrypoint.sh /app/entrypoint.sh
COPY server.py /app/server.py
COPY dashboard.py /app/dashboard.py
COPY requirements.txt /app/requirements.txt
COPY templates /app/templates
COPY static /app/static

RUN chmod +x /app/entrypoint.sh && \
    pip install --no-cache-dir -r requirements.txt

CMD ["/app/entrypoint.sh"]
