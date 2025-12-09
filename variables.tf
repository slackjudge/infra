# =============================================================================
# AWS Configuration
# =============================================================================
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "bj-ranking"
}

# =============================================================================
# Networking
# =============================================================================
variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

# =============================================================================
# Application
# =============================================================================
variable "app_port" {
  description = "Application container port"
  type        = number
  default     = 8080
}

variable "health_check_path" {
  description = "ALB health check path"
  type        = string
  default     = "/health"
}

variable "spring_profile" {
  description = "Spring Boot active profile (dev, prod)"
  type        = string
  default     = "dev"
}

# =============================================================================
# ECR
# =============================================================================
variable "ecr_image_retention_count" {
  description = "Number of images to retain in ECR"
  type        = number
  default     = 10
}

# =============================================================================
# Auto Scaling
# =============================================================================
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

# =============================================================================
# Cloudflare
# =============================================================================
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID (for Worker deployment)"
  type        = string
}

variable "domain_name" {
  description = "Root domain (e.g., example.com)"
  type        = string
}

# =============================================================================
# Secrets - PostgreSQL
# =============================================================================
variable "postgres_host" {
  description = "PostgreSQL host"
  type        = string
  sensitive   = true
}

variable "postgres_port" {
  description = "PostgreSQL port"
  type        = string
  default     = "5432"
}

variable "postgres_database" {
  description = "PostgreSQL database name"
  type        = string
  sensitive   = true
}

variable "postgres_user" {
  description = "PostgreSQL username"
  type        = string
  sensitive   = true
}

variable "postgres_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

# =============================================================================
# Secrets - MongoDB
# =============================================================================
variable "mongo_uri" {
  description = "MongoDB connection URI"
  type        = string
  sensitive   = true
}

variable "mongo_database" {
  description = "MongoDB database name"
  type        = string
  default     = "mini2"
}

variable "mongo_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

# =============================================================================
# Secrets - Redis
# =============================================================================
variable "redis_endpoint" {
  description = "Redis endpoint"
  type        = string
  sensitive   = true
}

variable "redis_username" {
  description = "Redis username"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
}

# =============================================================================
# Secrets - JWT
# =============================================================================
variable "jwt_access_secret" {
  description = "JWT Access Token secret"
  type        = string
  sensitive   = true
}

variable "jwt_refresh_secret" {
  description = "JWT Refresh Token secret"
  type        = string
  sensitive   = true
}

# =============================================================================
# Secrets - Slack
# =============================================================================
variable "slack_client_id" {
  description = "Slack OAuth client ID"
  type        = string
  sensitive   = true
}

variable "slack_client_secret" {
  description = "Slack OAuth client secret"
  type        = string
  sensitive   = true
}

variable "slack_redirect_uri" {
  description = "Slack OAuth redirect URI"
  type        = string
}

variable "slack_bot_token" {
  description = "Slack bot token"
  type        = string
  sensitive   = true
}
