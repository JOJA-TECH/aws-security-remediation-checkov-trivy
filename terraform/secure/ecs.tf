# ---------------------------------------------------------------------------
# ECS task & service -- SECURE
#
#   - Image pinned to an immutable reference (commit SHA tag or @sha256 digest).
#   - Container runs as a non-root user with a read-only root filesystem.
#   - No privileged mode, no plain-text secrets (SSM SecureString -> secrets).
#   - Tasks run in PRIVATE subnets without public IPs.
#   - Deployment circuit breaker rolls back on failures.
# ---------------------------------------------------------------------------

resource "aws_ecs_task_definition" "app" {
  family                   = "${local.name}-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name                   = "app"
      image                  = var.image_uri
      essential              = true
      readonlyRootFilesystem = true
      privileged             = false
      user                   = "10001:10001"
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "APP_NAME", value = "insecure-infra-demo" },
        { name = "PORT", value = tostring(var.container_port) }
      ]
      # Secrets are pulled from SSM SecureString at runtime, never stored in
      # the task definition or the image.
      secrets = [
        { name = "DB_PASSWORD", valueFrom = aws_ssm_parameter.db_password.arn },
        { name = "API_TOKEN", valueFrom = aws_ssm_parameter.api_token.arn }
      ]
      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://127.0.0.1:8080/health').status == 200 else 1)\""]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 10
      }
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "app"
        }
      }
    }
  ])

  tags = {
    Name = "${local.name}-task"
  }
}

resource "aws_ecs_service" "app" {
  name            = "${local.name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  platform_version                   = "LATEST"
  health_check_grace_period_seconds  = 30
  wait_for_steady_state              = true
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  network_configuration {
    subnets = aws_subnet.private[*].id
    security_groups = [
      aws_security_group.app.id
    ]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = var.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Name = "${local.name}-service"
  }
}
