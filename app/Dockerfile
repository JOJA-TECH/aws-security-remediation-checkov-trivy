# syntax=docker/dockerfile:1
# ---------------------------------------------------------------------------
# SECURE Dockerfile
#
# Hardening applied:
#   - Base image pinned by tag AND digest (no "latest", no drift).
#   - OS packages patched to the latest security update at build time.
#   - Dedicated non-root user (UID/GID 10001).
#   - No secrets baked into layers, env vars or build args.
#   - Minimal runtime: pip/setuptools/wheel removed (app is stdlib-only),
#     which eliminates the vendored build-tool CVEs.
#   - HEALTHCHECK for the /health endpoint.
# ---------------------------------------------------------------------------
FROM python:3.12-slim-bookworm@sha256:34386ef0cb081344d7ec1c103ba398e6e9f64e9ab3a1509accc92a4e24a07258

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# Apply available Debian security updates and drop the package index.
RUN apt-get update \
    && apt-get -y upgrade \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create an unprivileged user to run the application.
RUN groupadd --gid 10001 app \
    && useradd --uid 10001 --gid 10001 --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app

COPY src/ ./src/

# The application only uses the Python standard library. Remove pip and the
# build tooling so they are not present (and not scanned) at runtime.
RUN python -m pip uninstall -y pip setuptools wheel >/dev/null 2>&1 || true \
    && rm -rf /usr/local/lib/python3.12/site-packages/pip* \
              /usr/local/lib/python3.12/site-packages/setuptools* \
              /usr/local/lib/python3.12/site-packages/wheel* \
              /usr/local/lib/python3.12/site-packages/_distutils_hack \
              /usr/local/lib/python3.12/site-packages/distutils-precedence.pth \
    && rm -f /usr/local/bin/pip /usr/local/bin/pip3 /usr/local/bin/pip3.12 \
             /usr/local/bin/wheel

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
