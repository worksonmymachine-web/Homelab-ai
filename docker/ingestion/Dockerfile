FROM python:3.12-slim

LABEL org.opencontainers.image.title="homelab-ai-ingestion" \
      org.opencontainers.image.description="Ingestion .txt/.md verso PostgreSQL per homelab-ai" \
      io.homelab-ai.project="homelab-ai"

WORKDIR /app

RUN pip install --no-cache-dir psycopg2-binary \
    && useradd --create-home --shell /bin/bash ingest \
    && chown -R ingest:ingest /app

COPY --chown=ingest:ingest scripts/ingest.py .

USER ingest
ENTRYPOINT ["python", "ingest.py"]
