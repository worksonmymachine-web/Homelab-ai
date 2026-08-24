FROM debian:bookworm-slim

ARG SANDBOX_UID=1000
ARG SANDBOX_GID=1000

LABEL org.opencontainers.image.title="homelab-ai-sandbox" \
      org.opencontainers.image.description="Minimal non-root coding sandbox for homelab-ai" \
      io.homelab-ai.project="homelab-ai"

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/workspace

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       bash \
       build-essential \
       ca-certificates \
       cmake \
       curl \
       git \
       python3 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid "${SANDBOX_GID}" sandbox \
    && useradd --uid "${SANDBOX_UID}" --gid "${SANDBOX_GID}" --no-create-home --shell /bin/bash sandbox

WORKDIR /workspace
USER ${SANDBOX_UID}:${SANDBOX_GID}
CMD ["sleep", "infinity"]
