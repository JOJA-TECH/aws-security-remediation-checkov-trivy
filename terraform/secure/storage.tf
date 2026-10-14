# ---------------------------------------------------------------------------
# Storage -- SECURE
#
#   - Private bucket (all public access blocked).
#   - SSE-S3 encryption (AES256), versioning and lifecycle expiration.
#   - Used for ALB access logs; policy allows ONLY the ELB service account.
#
# NOTE: AWS ELB access-log delivery does NOT support SSE-KMS (customer-managed
# keys). The bucket must use SSE-S3 (AES256). See:
# https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html
# The CKV_AWS_145 exception is recorded in checkov/secure.yaml and AWS-0132 in
# trivy/secure.ignore.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "alb_logs" {
  bucket        = "${local.name}-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true

  tags = {
    Name = "${local.name}-alb-logs"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}

resource "aws_s3_bucket_notification" "alb_logs" {
  bucket      = aws_s3_bucket.alb_logs.id
  eventbridge = true
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid     = "AllowELBLogDelivery"
    effect  = "Allow"
    actions = ["s3:PutObject"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.elb_log_account_id}:root"]
    }

    resources = ["${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
  }

  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    resources = [
      aws_s3_bucket.alb_logs.arn,
      "${aws_s3_bucket.alb_logs.arn}/*"
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}
