# ---------------------------------------------------------------------------
# Application Load Balancer -- SECURE
#
#   - ALB placed in public subnets; tasks stay private.
#   - App reachable only through the ALB.
#   - Access logs shipped to the private, encrypted S3 bucket.
#   - Health checks target /health.
#
# EXCEPTION: HTTP-only listener. TLS termination (HTTPS) requires a domain and
# an ACM certificate, which are out of scope and would add cost. Documented as
# an accepted finding (CKV_AWS_2 / CKV_AWS_103). See docs/correcciones.md.
# ---------------------------------------------------------------------------

resource "aws_lb" "app" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false # Demo: allow easy teardown.
  drop_invalid_header_fields = true

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = "alb"
    enabled = true
  }

  # Ensure the bucket policy exists before the ALB tries to write logs.
  depends_on = [aws_s3_bucket_policy.alb_logs]

  tags = {
    Name = "${local.name}-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name        = "${local.name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name = "${local.name}-tg"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = {
    Name = "${local.name}-listener-http"
  }
}
