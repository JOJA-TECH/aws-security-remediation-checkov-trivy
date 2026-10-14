# ---------------------------------------------------------------------------
# IAM -- INSECURE
#
# Intentional issues:
#   - Task role has an inline policy granting Action "*" on Resource "*"
#     (CKV_AWS_1, CKV_AWS_40, CKV_AWS_355, CKV_AWS_356).
#   - Task role also receives the AWS-managed AdministratorAccess policy
#     (CKV_AWS_40).
#   - Trust policies are not scoped any tighter than necessary.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "ecs_tasks_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

# Execution role: pulls images and writes logs.
resource "aws_iam_role" "execution" {
  name               = "${local.name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = {
    Name = "${local.name}-ecs-execution"
  }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Task role: identity assumed by the application inside the container.
resource "aws_iam_role" "task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.ecs_tasks_assume.json

  tags = {
    Name = "${local.name}-ecs-task"
  }
}

# INSECURE: full administrative access for the application.
resource "aws_iam_role_policy_attachment" "task_admin" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# INSECURE: wildcard inline policy.
resource "aws_iam_role_policy" "task_wildcard" {
  name = "${local.name}-task-wildcard"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "FullAccess"
        Effect   = "Allow"
        Action   = "*"
        Resource = "*"
      }
    ]
  })
}
