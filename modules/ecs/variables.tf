variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Network
variable "subnet_ids" {
  description = "List of subnet IDs for ECS tasks"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

# IAM
variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "eventbridge_role_arn" {
  description = "EventBridge role ARN for scheduled tasks"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN for application-level AWS API calls (e.g., EventBridge PutEvents)"
  type        = string
}

# ALB
variable "target_group_arn" {
  description = "ALB target group ARN"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix for auto scaling metrics"
  type        = string
}

variable "target_group_arn_suffix" {
  description = "Target group ARN suffix for auto scaling metrics"
  type        = string
}

# Container Images
variable "api_image" {
  description = "API container image URL"
  type        = string
}

variable "worker_image" {
  description = "Worker container image URL"
  type        = string
}

# Spring Profile
variable "api_spring_profile" {
  description = "Spring Boot active profile for API (dev, prod)"
  type        = string
  default     = "dev"
}

variable "worker_spring_profile" {
  description = "Spring Boot active profile for Worker (dev, prod)"
  type        = string
  default     = "prod"
}

# SSM Parameter ARNs - loki
variable "loki_uri_ssm_arn" {
  description = "SSM parameter ARN for LOKI_URI"
  type        = string
}

# SSM Parameter ARNs - PostgreSQL
variable "postgres_host_ssm_arn" {
  description = "SSM parameter ARN for POSTGRES_HOST"
  type        = string
}

variable "postgres_port_ssm_arn" {
  description = "SSM parameter ARN for POSTGRES_PORT"
  type        = string
}

variable "postgres_database_ssm_arn" {
  description = "SSM parameter ARN for POSTGRES_DATABASE"
  type        = string
}

variable "postgres_user_ssm_arn" {
  description = "SSM parameter ARN for POSTGRES_USER"
  type        = string
}

variable "postgres_password_ssm_arn" {
  description = "SSM parameter ARN for POSTGRES_PASSWORD"
  type        = string
}

# SSM Parameter ARNs - MongoDB
variable "mongo_uri_ssm_arn" {
  description = "SSM parameter ARN for MONGO_URI"
  type        = string
}

variable "mongo_database_ssm_arn" {
  description = "SSM parameter ARN for MONGO_DATABASE"
  type        = string
}

variable "mongo_user_name_ssm_arn" {
  description = "SSM parameter ARN for MONGO_USER_NAME"
  type        = string
}

variable "mongo_password_ssm_arn" {
  description = "SSM parameter ARN for MONGO_PASSWORD"
  type        = string
}

# SSM Parameter ARNs - Redis
variable "redis_endpoint_ssm_arn" {
  description = "SSM parameter ARN for REDIS_ENDPOINT"
  type        = string
}

variable "redis_username_ssm_arn" {
  description = "SSM parameter ARN for REDIS_USERNAME"
  type        = string
}

variable "redis_password_ssm_arn" {
  description = "SSM parameter ARN for REDIS_PASSWORD"
  type        = string
}

# SSM Parameter ARNs - Frontend
variable "frontend_url_ssm_arn" {
  description = "SSM parameter ARN for FRONTEND_URL"
  type        = string
}

# SSM Parameter ARNs - JWT
variable "jwt_access_secret_ssm_arn" {
  description = "SSM parameter ARN for DEV_ACCESS_SECRET"
  type        = string
}

variable "jwt_refresh_secret_ssm_arn" {
  description = "SSM parameter ARN for DEV_REFRESH_SECRET"
  type        = string
}

# SSM Parameter ARNs - Slack
variable "slack_client_id_ssm_arn" {
  description = "SSM parameter ARN for SLACK_CLIENT_ID"
  type        = string
}

variable "slack_client_secret_ssm_arn" {
  description = "SSM parameter ARN for SLACK_CLIENT_SECRET"
  type        = string
}

variable "slack_redirect_uri_ssm_arn" {
  description = "SSM parameter ARN for SLACK_REDIRECT_URI"
  type        = string
}

variable "slack_bot_token_ssm_arn" {
  description = "SSM parameter ARN for SLACK_BOT_TOKEN"
  type        = string
}

# Auto Scaling
variable "api_min_count" {
  description = "Minimum number of API tasks"
  type        = number
  default     = 1
}

variable "api_max_count" {
  description = "Maximum number of API tasks"
  type        = number
  default     = 3
}

variable "cpu_target_value" {
  description = "Target CPU utilization percentage for scaling"
  type        = number
  default     = 70
}

variable "requests_per_target" {
  description = "Target requests per target for ALB-based scaling"
  type        = number
  default     = 1000
}

variable "health_check_grace_period_seconds" {
  description = "Seconds to wait before starting health checks (Spring Boot startup ~90s)"
  type        = number
  default     = 120
}

# Task Sizing
variable "api_cpu" {
  description = "API task CPU units"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "API task memory (MB)"
  type        = number
  default     = 512
}

variable "worker_cpu" {
  description = "Worker task CPU units"
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Worker task memory (MB)"
  type        = number
  default     = 512
}

variable "app_port" {
  description = "Application container port"
  type        = number
  default     = 8080
}

# Scheduling
variable "worker_schedule" {
  description = "Worker cron schedule expression"
  type        = string
  default     = "cron(0 * * * ? *)"
}

# Logging
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}
variable "slack_webhook_url_ssm_arn" {
  description = "SSM parameter ARN for SLACK_WEBHOOK_URL"
  type        = string
}

# -----------------------------------------------------------------------------
# EC2 Configuration (for API service)
# -----------------------------------------------------------------------------
variable "ecs_instance_profile_name" {
  description = "ECS EC2 instance profile name"
  type        = string
}

variable "ec2_instance_type" {
  description = "EC2 instance type for ECS cluster"
  type        = string
  default     = "t3.small"
}

variable "ec2_min_count" {
  description = "Minimum number of EC2 instances"
  type        = number
  default     = 1
}

variable "ec2_max_count" {
  description = "Maximum number of EC2 instances"
  type        = number
  default     = 2
}

variable "ec2_desired_count" {
  description = "Desired number of EC2 instances"
  type        = number
  default     = 1
}

variable "loki_url" {
  description = "Loki push URL for Promtail (e.g., http://loki:3100)"
  type        = string
}

variable "promtail_image" {
  description = "Promtail container image URL"
  type        = string
}
