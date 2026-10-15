variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "github_org" {
  description = "GitHub organization that owns the repository."
  type        = string
  default     = "JOJA-TECH"
}

variable "github_repo" {
  description = "GitHub repository name."
  type        = string
  default     = "aws-security-remediation-checkov-trivy"
}

variable "role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  type        = string
  default     = "github-actions-aws-remediation"
}

variable "allowed_subjects" {
  description = "Allowed OIDC subject claims (repo/branch/environment restrictions)."
  type        = list(string)
  # GitHub now emits the subject with immutable numeric IDs
  # (repo:OWNER@OWNER_ID/REPO@REPO_ID:...). Both the legacy and the
  # immutable-ID forms are allowed so the trust policy keeps working
  # regardless of which format the token uses.
  default = [
    "repo:JOJA-TECH/aws-security-remediation-checkov-trivy:ref:refs/heads/main",
    "repo:JOJA-TECH/aws-security-remediation-checkov-trivy:environment:production",
    "repo:JOJA-TECH@339326270/aws-security-remediation-checkov-trivy@1419424003:ref:refs/heads/main",
    "repo:JOJA-TECH@339326270/aws-security-remediation-checkov-trivy@1419424003:environment:production"
  ]
}

variable "tags" {
  description = "Tags applied to bootstrap resources."
  type        = map(string)
  default = {
    Equipo      = "devsecops"
    Proyecto    = "aws-security-remediation"
    Ambiente    = "bootstrap"
    Responsable = "arquitectura-uc"
  }
}
