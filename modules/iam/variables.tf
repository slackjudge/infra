variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "ssm_parameter_prefix" {
  description = "SSM parameter path prefix (e.g., /bj-ranking/*)"
  type        = string
  default     = "/bj-ranking/*"
}
