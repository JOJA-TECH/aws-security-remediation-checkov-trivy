variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as resource prefix."
  type        = string
  default     = "secure-demo"
}

variable "environment" {
  description = "Deployment environment (dev/staging/prod)."
  type        = string
  default     = "dev"
}

variable "team" {
  description = "Team responsible for the resources."
  type        = string
  default     = "devsecops"
}

variable "owner" {
  description = "Owner/responsible person for the resources."
  type        = string
  default     = "arquitectura-uc"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.30.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (ALB / NAT). One per AZ."
  type        = list(string)
  default     = ["10.30.0.0/24", "10.30.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for the private subnets (ECS tasks). One per AZ."
  type        = list(string)
  default     = ["10.30.10.0/24", "10.30.11.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "image_uri" {
  description = "Fully qualified container image URI. MUST be immutable (commit SHA tag or @sha256 digest). 'latest' is rejected."
  type        = string

  validation {
    condition     = !can(regex(":latest$", var.image_uri))
    error_message = "image_uri must not use the mutable 'latest' tag. Use a commit SHA tag or an image digest (@sha256:...)."
  }

  validation {
    condition     = can(regex("@sha256:", var.image_uri)) || can(regex(":[0-9a-f]{7,64}$", var.image_uri))
    error_message = "image_uri must be pinned to an immutable reference (commit SHA tag or @sha256 digest)."
  }
}

variable "task_cpu" {
  description = "Fargate task CPU units (256 = 0.25 vCPU, minimum allowed)."
  type        = number
  default     = 256
}

variable "task_memory" {
  description = "Fargate task memory in MiB (512 is the minimum for 256 CPU)."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Number of running tasks. Keep at 1 to control cost."
  type        = number
  default     = 1
}

variable "container_port" {
  description = "Port the application listens on inside the container."
  type        = number
  default     = 8080
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 7
}

variable "allowed_http_cidrs" {
  description = "CIDR blocks allowed to reach the load balancer on HTTP. Narrow this in production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "elb_log_account_id" {
  description = "AWS account ID that ELB uses to deliver access logs for the selected region (defaults to us-east-1)."
  type        = string
  default     = "127311923021"
}
