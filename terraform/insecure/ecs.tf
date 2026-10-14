# ---------------------------------------------------------------------------
# ECS task & service -- INSECURE
#
# Intentional issues:
#   - Image referenced by mutable tag "latest" (CKV_AWS_250 family / supply chain).
#   - Container runs as root: no "user", no "readonlyRootFilesystem",
#     explicit privileged (CKV_AWS_22, CKV_AWS_336).
#   - Secrets passed as plain environment variables (Trivy secret scan).
#   - Task runs in public subnets with a public IP (CKV_AWS_130).
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
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:${var.image_tag}"
      essential = true
      # INSECURE: runs as root, writable root filesystem, privileged.
      privileged             = true
      readonlyRootFilesystem = false
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      # INSECURE: fake secrets in plain-text environment variables.
      # (Values are FAKE and match documented secret-scanner patterns only to
      #  make Trivy report them during the exercise.)
      environment = [
        { name = "APP_VERSION", value = var.image_tag },
        { name = "DB_USER", value = "admin" },
        { name = "DB_PASSWORD", value = "SuperSecret123!" },
        { name = "API_TOKEN", value = "ghp_FAKEfakeFAKEfake1234567890abcdefghij" },
        { name = "AWS_ACCESS_KEY_ID", value = "AKIAFAKEKEY123456789" },
        { name = "AWS_SECRET_ACCESS_KEY", value = "FAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKEFAKE1234" }
      ]
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

  network_configuration {
    subnets = aws_subnet.public[*].id
    security_groups = [
      aws_security_group.app.id
    ]
    # INSECURE: assigns a public IP directly to the task.
    assign_public_ip = true
  }

  tags = {
    Name = "${local.name}-service"
  }
}
