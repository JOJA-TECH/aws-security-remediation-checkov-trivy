# ---------------------------------------------------------------------------
# Storage -- REMEDIATED
#
# Fixed (was INSECURE):
#   - Removed the public-read ACL and the wildcard-principal bucket policy
#     (CKV_AWS_20).
#   - Public access fully blocked (CKV_AWS_53, CKV_AWS_54, CKV_AWS_55,
#     CKV_AWS_56).
#   - Default encryption with the customer-managed KMS key (CKV_AWS_19).
#   - Versioning enabled (CKV_AWS_21) with a lifecycle rule.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name}-artifacts"
  force_destroy = true

  tags = {
    Name = "${local.name}-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-noncurrent"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
