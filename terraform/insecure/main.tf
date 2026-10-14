# ---------------------------------------------------------------------------
# ECS cluster & logging -- INSECURE
#
# Intentional issues:
#   - Container Insights disabled (CKV_AWS_65).
#   - CloudWatch log group without KMS encryption (CKV_AWS_158) and without a
#     retention policy (CKV_AWS_66).
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = local.name

  # INSECURE: container insights not enabled.

  tags = {
    Name = "${local.name}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name = "/ecs/${local.name}-app"

  # INSECURE: no kms_key_id and no retention_in_days.

  tags = {
    Name = "${local.name}-logs"
  }
}
