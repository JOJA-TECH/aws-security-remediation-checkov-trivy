#!/usr/bin/env bash
#
# Verify that the deployed application responds on /health.
#
# Usage:
#   scripts/verify.sh <HEALTH_URL>
# Example:
#   scripts/verify.sh http://my-alb-123456.us-east-1.elb.amazonaws.com/health
set -euo pipefail

HEALTH_URL="${1:-}"
if [[ -z "$HEALTH_URL" ]]; then
  echo "Usage: $0 <HEALTH_URL>" >&2
  exit 1
fi

MAX_ATTEMPTS="${MAX_ATTEMPTS:-18}"
SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

echo "Testing ${HEALTH_URL}"
for attempt in $(seq 1 "$MAX_ATTEMPTS"); do
  if body="$(curl -fsS --max-time 5 "$HEALTH_URL" 2>/dev/null)"; then
    echo ""
    echo "OK (attempt ${attempt}): ${body}"
    exit 0
  fi
  echo "Attempt ${attempt}/${MAX_ATTEMPTS} failed; retrying in ${SLEEP_SECONDS}s..."
  sleep "$SLEEP_SECONDS"
done

echo "FAILED: no healthy response after ${MAX_ATTEMPTS} attempts." >&2
exit 1
