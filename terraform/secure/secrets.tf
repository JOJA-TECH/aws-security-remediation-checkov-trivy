# ---------------------------------------------------------------------------
# Secrets -- SECURE
#
#   - No secrets in code, Dockerfile, Terraform literals or plain env vars.
#   - Generated at apply time and stored as SSM SecureString (KMS encrypted).
#   - Injected into the container via the ECS "secrets" block (valueFrom).
#
# NOTE: values still land in Terraform state. Use an encrypted remote backend
# (S3 + KMS + DynamoDB lock) for real environments.
# ---------------------------------------------------------------------------

resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "api_token" {
  length  = 40
  special = false
}

resource "aws_ssm_parameter" "db_password" {
  name        = "/${local.name}/db/password"
  description = "Database password for the demo application."
  type        = "SecureString"
  value       = random_password.db_password.result
  key_id      = aws_kms_key.main.arn

  tags = {
    Name = "${local.name}-db-password"
  }
}

resource "aws_ssm_parameter" "api_token" {
  name        = "/${local.name}/api/token"
  description = "Internal API token for the demo application."
  type        = "SecureString"
  value       = random_password.api_token.result
  key_id      = aws_kms_key.main.arn

  tags = {
    Name = "${local.name}-api-token"
  }
}
