# ---------------------------------------------------------------------------
# ECS cluster & logging -- REMEDIATED
#
# Fixed (was INSECURE):
#   - Container Insights enabled (CKV_AWS_65).
#   - CloudWatch log group encrypted with the customer-managed KMS key
#     (CKV_AWS_158) with a bounded retention period (CKV_AWS_66).
# ---------------------------------------------------------------------------

resource "aws_ecs_cluster" "main" {
  name = local.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${local.name}-cluster"
  }
}

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${local.name}-app"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Name = "${local.name}-logs"
  }
}
