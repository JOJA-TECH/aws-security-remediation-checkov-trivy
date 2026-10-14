output "ecr_repository_url" {
  description = "ECR repository URL for the application image (insecure)."
  value       = aws_ecr_repository.app.repository_url
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.main.name
}

output "ecs_service_name" {
  description = "ECS service name."
  value       = aws_ecs_service.app.name
}

output "security_group_id" {
  description = "Application security group id (insecure)."
  value       = aws_security_group.app.id
}

output "app_access_hint" {
  description = "How to reach the application. The task gets a public IP (INSECURE); inspect it with the AWS CLI."
  value       = "http://<public-ip-of-task>:${var.container_port}/health  (aws ecs list-tasks / describe-tasks to find the ENI public IP)"
}

output "s3_bucket_name" {
  description = "Public artifacts bucket name (insecure)."
  value       = aws_s3_bucket.artifacts.bucket
}
