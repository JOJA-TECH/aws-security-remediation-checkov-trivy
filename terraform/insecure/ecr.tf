# ---------------------------------------------------------------------------
# ECR -- REMEDIATED
#
# Fixed (was INSECURE):
#   - Image tags are IMMUTABLE (CKV_AWS_51).
#   - Scan on push enabled (CKV_AWS_163).
#   - Encrypted with the customer-managed KMS key (CKV_AWS_136).
#   - Removed the wildcard-principal repository policy.
#   - Lifecycle policy keeps the repository small (cost control).
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "app" {
  name                 = "${local.name}-app"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.main.arn
  }

  tags = {
    Name = "${local.name}-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images after 14 days."
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Keep only the last 30 tagged images."
        selection = {
          tagStatus      = "tagged"
          tagPatternList = ["*"]
          countType      = "imageCountMoreThan"
          countNumber    = 30
        }
        action = { type = "expire" }
      }
    ]
  })
}
