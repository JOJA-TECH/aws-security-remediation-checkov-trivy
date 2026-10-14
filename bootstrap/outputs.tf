output "github_actions_role_arn" {
  description = "ARN of the IAM role GitHub Actions assumes via OIDC. Set this as the AWS_ROLE_ARN secret/variable in the repository."
  value       = aws_iam_role.github_actions.arn
}

output "oidc_provider_arn" {
  description = "ARN of the GitHub OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "aws_account_id" {
  description = "Current AWS account id."
  value       = data.aws_caller_identity.current.account_id
}

output "tfstate_bucket" {
  description = "S3 bucket used for Terraform remote state."
  value       = aws_s3_bucket.tfstate.bucket
}

output "tflock_table" {
  description = "DynamoDB table used for Terraform state locking."
  value       = aws_dynamodb_table.tflock.name
}
