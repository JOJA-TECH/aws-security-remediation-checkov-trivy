# ---------------------------------------------------------------------------
# Terraform remote state backend
#
# Creates the S3 bucket and DynamoDB table used by the secure stack's S3
# backend. Run this bootstrap stack ONCE with local state, then configure the
# GitHub Actions pipeline to use the outputs.
#
# Bootstrap itself intentionally uses local state (chicken-and-egg).
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket        = "${var.github_repo}-tfstate-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_dynamodb_table" "tflock" {
  name         = "${var.github_repo}-tflock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  tags = var.tags
}
