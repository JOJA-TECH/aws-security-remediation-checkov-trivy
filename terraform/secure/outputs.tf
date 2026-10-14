output "app_url" {
  description = "Public URL of the application (via the load balancer)."
  value       = "http://${aws_lb.app.dns_name}"
}

output "health_url" {
  description = "Health check URL."
  value       = "http://${aws_lb.app.dns_name}/health"
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = aws_lb.app.dns_name
}

output "ecr_repository_url" {
  description = "ECR repository URL for the application image (secure)."
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

output "app_security_group_id" {
  description = "Application security group id."
  value       = aws_security_group.app.id
}

output "kms_key_arn" {
  description = "Customer-managed KMS key ARN."
  value       = aws_kms_key.main.arn
}

output "alb_logs_bucket" {
  description = "S3 bucket receiving ALB access logs."
  value       = aws_s3_bucket.alb_logs.bucket
}
