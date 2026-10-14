# ---------------------------------------------------------------------------
# Security groups -- INSECURE
#
# Intentional issues:
#   - SSH (22) open to the whole internet (CKV_AWS_24).
#   - HTTP (80) open to the whole internet (CKV_AWS_260).
#   - Application port (8080) open to the whole internet (CKV_AWS_260/CKV_AWS_277 family).
#   - Rules have no descriptions (CKV_AWS_23).
#   - Unrestricted egress.
# ---------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name        = "${local.name}-app-sg"
  description = "Security group for the demo app (INSECURE)"
  vpc_id      = aws_vpc.main.id

  # INSECURE: administrative port exposed to the internet.
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.container_port
    to_port     = var.container_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # INSECURE: unrestricted egress.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-app-sg"
  }
}
