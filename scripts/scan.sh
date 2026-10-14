#!/usr/bin/env bash
#
# Run the full local security scan used by the CI "Security" workflow.
#
# Usage:
#   scripts/scan.sh [PROJECT]
#
# Requires: checkov, trivy, docker (for the image scans), terraform.
# Results are written to ./reports/.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

REPORTS_DIR="$ROOT_DIR/reports"
mkdir -p "$REPORTS_DIR"

SECURE_IMAGE="secure-demo:local"
INSECURE_IMAGE="insecure-demo:local"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# Stacks:
#   terraform/baseline  -> original intentionally-vulnerable code (informational)
#   terraform/insecure  -> same stack AFTER the remediation commits (gate)
#   terraform/secure    -> production-grade redesign (gate)
log "Terraform fmt -check"
(cd terraform/baseline && terraform fmt -check -recursive -diff)
(cd terraform/insecure && terraform fmt -check -recursive -diff)
(cd terraform/secure && terraform fmt -check -recursive -diff)

log "Terraform validate (baseline)"
(cd terraform/baseline && terraform init -backend=false -input=false >/dev/null && terraform validate)

log "Terraform validate (remediated)"
(cd terraform/insecure && terraform init -backend=false -input=false >/dev/null && terraform validate)

log "Terraform validate (secure)"
(cd terraform/secure && terraform init -backend=false -input=false >/dev/null && terraform validate)

if have checkov; then
  log "Checkov: baseline (informational, all findings visible)"
  checkov -d terraform/baseline --framework terraform \
    --output cli --output json --output-file-path "$REPORTS_DIR/checkov-baseline" \
    --soft-fail --compact || true

  log "Checkov: remediated (gate, must be clean)"
  checkov -d terraform/insecure --framework terraform --config-file checkov/remediated.yaml \
    --output cli --output json --output-file-path "$REPORTS_DIR/checkov-remediated" --compact

  log "Checkov: secure (gate, must be clean)"
  checkov -d terraform/secure --framework terraform --config-file checkov/secure.yaml \
    --output cli --output json --output-file-path "$REPORTS_DIR/checkov-secure" --compact
else
  echo "checkov not found - skipping. Install: pip install checkov" >&2
fi

if have trivy; then
  log "Trivy config: baseline (informational)"
  trivy config --quiet terraform/baseline > "$REPORTS_DIR/trivy-config-baseline.txt" || true

  log "Trivy config: remediated (gate)"
  trivy config --quiet --ignorefile trivy/remediated.ignore --severity CRITICAL,HIGH \
    --exit-code 1 terraform/insecure | tee "$REPORTS_DIR/trivy-config-remediated.txt"

  log "Trivy config: secure (gate)"
  trivy config --quiet --ignorefile trivy/secure.ignore --severity CRITICAL,HIGH \
    --exit-code 1 terraform/secure | tee "$REPORTS_DIR/trivy-config-secure.txt"

  log "Trivy fs: secrets + misconfig (gate)"
  trivy fs --quiet --scanners secret,misconfig \
    --skip-dirs terraform/baseline --skip-dirs docs --skip-dirs .git \
    --skip-files app/Dockerfile.insecure --ignorefile trivy/secure.ignore \
    --severity CRITICAL,HIGH --exit-code 1 . | tee "$REPORTS_DIR/trivy-fs-secure.txt"
else
  echo "trivy not found - skipping. See README for install." >&2
fi

if have docker && docker info >/dev/null 2>&1; then
  log "Build images"
  docker build --build-arg APP_VERSION=local --build-arg GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo local)" \
    -t "$SECURE_IMAGE" ./app
  docker build -f app/Dockerfile.insecure -t "$INSECURE_IMAGE" ./app

  if have trivy; then
    log "Trivy image: secure (gate, CRITICAL/HIGH, ignore unfixed)"
    trivy image --quiet --severity CRITICAL,HIGH --ignore-unfixed \
      --exit-code 1 "$SECURE_IMAGE" | tee "$REPORTS_DIR/trivy-image-secure.txt"

    log "Trivy image: insecure (informational)"
    trivy image --quiet "$INSECURE_IMAGE" | tee "$REPORTS_DIR/trivy-image-insecure.txt" || true
  fi
else
  echo "docker daemon not available - skipping image scans." >&2
fi

log "Done. Reports in $REPORTS_DIR"
