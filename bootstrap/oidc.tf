# ---------------------------------------------------------------------------
# GitHub Actions OIDC provider
#
# Allows GitHub Actions to assume an AWS role using short-lived credentials
# instead of long-lived access keys stored in the repository.
# ---------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # Thumbprint of the GitHub OIDC root CA (stable, documented by AWS/GitHub).
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = var.tags
}
