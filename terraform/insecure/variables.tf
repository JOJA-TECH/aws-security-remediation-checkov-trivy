variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name used as resource prefix."
  type        = string
  default     = "insecure-demo"
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
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for the public subnets (one per AZ)."
  type        = list(string)
  default     = ["10.20.1.0/24", "10.20.2.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "image_tag" {
  description = "Container image tag to deploy. INSECURE: defaults to mutable 'latest'."
  type        = string
  default     = "latest"
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
  description = "CloudWatch log retention in days. Minimum 365 to satisfy CKV_AWS_338."
  type        = number
  default     = 365
}
