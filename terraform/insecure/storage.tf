# ---------------------------------------------------------------------------
# Storage -- INSECURE
#
# Intentional issues:
#   - Public-read ACL on the bucket (CKV_AWS_20).
#   - Public access block disabled / permissive (CKV_AWS_53, CKV_AWS_54,
#     CKV_AWS_55, CKV_AWS_56).
#   - No default encryption (CKV_AWS_19).
#   - No versioning (CKV_AWS_21) and no access logging (CKV_AWS_18).
#   - Bucket policy grants a wildcard principal read access.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket        = "${local.name}-artifacts"
  force_destroy = true

  tags = {
    Name = "${local.name}-artifacts"
  }
}

resource "aws_s3_bucket_ownership_controls" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    object_ownership = "ObjectWriter"
  }
}

resource "aws_s3_bucket_acl" "artifacts" {
  depends_on = [aws_s3_bucket_ownership_controls.artifacts]

  bucket = aws_s3_bucket.artifacts.id
  acl    = "public-read"
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "artifacts_public" {
  depends_on = [aws_s3_bucket_public_access_block.artifacts]

  bucket = aws_s3_bucket.artifacts.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicRead"
        Effect    = "Allow"
        Principal = "*"
        Action    = ["s3:GetObject"]
        Resource  = "${aws_s3_bucket.artifacts.arn}/*"
      }
    ]
  })
}
