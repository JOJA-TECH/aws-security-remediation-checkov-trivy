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
