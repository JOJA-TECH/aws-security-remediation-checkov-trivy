# ---------------------------------------------------------------------------
# ECR -- INSECURE
#
# Intentional issues:
#   - Mutable image tags allowed (CKV_AWS_51).
#   - No image scanning on push (CKV_AWS_163).
#   - Default AES256 encryption instead of a customer-managed KMS key (CKV_AWS_136).
#   - Repository policy grants a wildcard principal pull access.
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "${local.name}-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name = "${local.name}-ecr"
  }
}

resource "aws_ecr_repository_policy" "app_public" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowPullAnyPrincipal"
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
      }
    ]
  })
}
