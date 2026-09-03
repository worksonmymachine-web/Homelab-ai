FROM python:3.12-slim

LABEL org.opencontainers.image.title="homelab-ai-ingestion" \
      org.opencontainers.image.description="Ingestion .txt/.md/.pdf verso PostgreSQL per homelab-ai" \
      io.homelab-ai.project="homelab-ai"

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends poppler-utils \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir psycopg2-binary \
    && useradd --create-home --shell /bin/bash ingest \
    && chown -R ingest:ingest /app

COPY --chown=ingest:ingest scripts/ingest.py .

USER ingest
ENTRYPOINT ["python", "ingest.py"]
