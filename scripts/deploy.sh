#!/usr/bin/env bash
#
# Build, push and deploy the SECURE stack to AWS.
#
# Usage:
#   scripts/deploy.sh [ENVIRONMENT]
#
# Environment variables:
#   AWS_REGION        (default: us-east-1)
#   PROJECT           (default: secure-demo)
#   TF_STATE_BUCKET   S3 bucket for remote state (required)
#   TF_LOCK_TABLE     DynamoDB lock table (required)
#
# Prerequisites: aws CLI v2 authenticated, docker, terraform >= 1.5.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ENVIRONMENT="${1:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT:-secure-demo}"
TF_DIR="terraform/secure"

if [[ -z "${TF_STATE_BUCKET:-}" || -z "${TF_LOCK_TABLE:-}" ]]; then
  echo "ERROR: TF_STATE_BUCKET and TF_LOCK_TABLE must be set (see bootstrap/)." >&2
  exit 1
fi

IMAGE_TAG="$(git rev-parse --short HEAD 2>/dev/null || echo local)"

log() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY="${REGISTRY}/${PROJECT}-${ENVIRONMENT}-app"

log "Authenticating to ECR"
aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$REGISTRY"

log "Terraform init"
(cd "$TF_DIR" && terraform init -input=false \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
  -backend-config="encrypt=true")

log "Stage 1: create ECR repository"
(cd "$TF_DIR" && terraform apply -auto-approve -input=false \
  -target=aws_ecr_repository.app \
  -var "project=${PROJECT}" -var "environment=${ENVIRONMENT}" -var "region=${AWS_REGION}" \
  -var "image_uri=placeholder@sha256:$(printf '0%.0s' $(seq 1 64))")

log "Build and push image (tag: ${IMAGE_TAG})"
docker build --build-arg APP_VERSION="${IMAGE_TAG}" --build-arg GIT_COMMIT="$IMAGE_TAG" \
  -t "${ECR_REPOSITORY}:${IMAGE_TAG}" ./app
docker push "${ECR_REPOSITORY}:${IMAGE_TAG}"

DIGEST="$(aws ecr describe-images --region "$AWS_REGION" \
  --repository-name "${PROJECT}-${ENVIRONMENT}-app" \
  --image-ids imageTag="${IMAGE_TAG}" \
  --query 'imageDetails[0].imageDigest' --output text)"
IMAGE_URI="${ECR_REPOSITORY}@${DIGEST}"
log "Immutable image reference: ${IMAGE_URI}"

log "Stage 2: apply the full secure stack"
(cd "$TF_DIR" && terraform apply -auto-approve -input=false \
  -var "project=${PROJECT}" -var "environment=${ENVIRONMENT}" -var "region=${AWS_REGION}" \
  -var "image_uri=${IMAGE_URI}")

CLUSTER="$(cd "$TF_DIR" && terraform output -raw ecs_cluster_name)"
SERVICE="$(cd "$TF_DIR" && terraform output -raw ecs_service_name)"
HEALTH_URL="$(cd "$TF_DIR" && terraform output -raw health_url)"
APP_URL="$(cd "$TF_DIR" && terraform output -raw app_url)"

log "Waiting for ECS service to become stable"
aws ecs wait services-stable --region "$AWS_REGION" --cluster "$CLUSTER" --services "$SERVICE"

log "Application URL: $APP_URL"
log "Health URL:      $HEALTH_URL"

"$ROOT_DIR/scripts/verify.sh" "$HEALTH_URL"
