terraform {
  required_version = ">= 1.5.0"

  # Partial S3 backend. bucket/region/dynamodb_table are supplied at init time
  # via -backend-config (see README and the deploy workflow). For local
  # validation without AWS, run: terraform init -backend=false
  backend "s3" {
    key = "secure/terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}
