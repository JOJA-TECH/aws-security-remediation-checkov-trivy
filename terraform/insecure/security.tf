# ---------------------------------------------------------------------------
# Security groups -- REMEDIATED
#
# Fixed (was INSECURE):
#   - Removed the administrative SSH (22) rule exposed to the internet.
#   - Removed the unused HTTP (80) rule exposed to the internet.
#   - Every group and every rule now has a description.
#   - Egress restricted to HTTPS (image pull / AWS APIs / logs) and DNS.
#   - The VPC default security group is locked down (no rules).
#
# Accepted risk: the application port (8080) remains reachable from the
# internet because this stack publishes the app directly on a public IP
# (no load balancer). Ingress is limited to the single application port.
# See docs/remediacion.md.
# ---------------------------------------------------------------------------

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.name}-default-sg"
  }
}

resource "aws_security_group" "app" {
  name_prefix = "${local.name}-app-sg-"
  description = "Controls traffic to the demo application (remediated)."
  vpc_id      = aws_vpc.main.id

  # The old (insecure) group cannot be deleted while the running ECS task still
  # holds an ENI in it, so create the remediated group first and repoint the
  # service before the old one is destroyed.
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${local.name}-app-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_public" {
  security_group_id = aws_security_group.app.id
  description       = "Allow inbound application traffic from the internet (public demo)."
  from_port         = var.container_port
  to_port           = var.container_port
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "Allow outbound HTTPS to AWS APIs and image registries."
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "app_dns_udp" {
  security_group_id = aws_security_group.app.id
  description       = "Allow DNS resolution inside the VPC (UDP)."
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "app_dns_tcp" {
  security_group_id = aws_security_group.app.id
  description       = "Allow DNS resolution inside the VPC (TCP fallback)."
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = var.vpc_cidr
}
