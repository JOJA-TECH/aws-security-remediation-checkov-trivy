# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# SECURE Dockerfile
#
# Hardening applied:
#   - Pinned base image (no "latest").
#   - Dedicated non-root user (UID/GID 10001).
#   - No secrets baked into layers, env vars or build args.
#   - Minimal package set + no build cache.
#   - HEALTHCHECK for the /health endpoint.
# ---------------------------------------------------------------------------
FROM python:3.12.6-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Create an unprivileged user to run the application.
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY src/ ./src/

# Version metadata is injected at build time (no secrets here).
ARG APP_VERSION=dev
ARG GIT_COMMIT=unknown
ENV APP_NAME=insecure-infra-demo \
    APP_VERSION=${APP_VERSION} \
    GIT_COMMIT=${GIT_COMMIT} \
    PORT=8080

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health').status == 200 else 1)"

CMD ["python", "src/main.py"]
