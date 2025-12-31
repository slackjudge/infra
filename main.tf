# =============================================================================
# Providers
# =============================================================================
provider "aws" {
  region = var.aws_region
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# =============================================================================
# Module Calls
# =============================================================================

# Networking (VPC, Subnets, IGW, Route Tables)
module "networking" {
  source       = "./modules/networking"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

# Security Groups (ALB, ECS)
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  vpc_id       = module.networking.vpc_id
  app_port     = var.app_port
}

# IAM Roles (ECS Execution, EventBridge)
module "iam" {
  source               = "./modules/iam"
  project_name         = var.project_name
  aws_region           = var.aws_region
  ssm_parameter_prefix = "/bj-ranking/*"
}

# ECR Repositories (API, Worker)
module "ecr" {
  source                = "./modules/ecr"
  project_name          = var.project_name
  image_retention_count = var.ecr_image_retention_count
}

# S3 Frontend (Static Website Hosting)
module "s3_frontend" {
  source       = "./modules/s3_frontend"
  project_name = var.project_name
}

# ALB (Application Load Balancer)
module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  security_group_id = module.security.alb_security_group_id
  app_port          = var.app_port
  health_check_path = var.health_check_path
}

# ECS (Cluster, Tasks, Service, Auto Scaling, EventBridge)
module "ecs" {
  source                  = "./modules/ecs"
  project_name            = var.project_name
  aws_region              = var.aws_region
  subnet_ids              = module.networking.public_subnet_ids
  ecs_security_group_id   = module.security.ecs_security_group_id
  execution_role_arn      = module.iam.ecs_execution_role_arn
  task_role_arn           = module.iam.ecs_task_role_arn
  eventbridge_role_arn    = module.iam.eventbridge_role_arn
  target_group_arn        = module.alb.target_group_arn
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  # Container images (use ECR URLs)
  api_image      = "${module.ecr.api_repository_url}:latest"
  worker_image   = "${module.ecr.worker_repository_url}:latest"
  promtail_image = "${module.ecr.promtail_repository_url}:latest"

  # Spring Profile
  api_spring_profile    = var.api_spring_profile
  worker_spring_profile = var.worker_spring_profile

  # EC2 Configuration (for API service)
  ecs_instance_profile_name = module.iam.ecs_instance_profile_name
  ec2_instance_type         = var.ec2_instance_type
  ec2_min_count             = var.ec2_min_count
  ec2_max_count             = var.ec2_max_count
  ec2_desired_count         = var.ec2_desired_count
  loki_url                  = var.loki_url

  # SSM Parameter ARNs
  postgres_host_ssm_arn       = aws_ssm_parameter.postgres_host.arn
  postgres_port_ssm_arn       = aws_ssm_parameter.postgres_port.arn
  postgres_database_ssm_arn   = aws_ssm_parameter.postgres_database.arn
  postgres_user_ssm_arn       = aws_ssm_parameter.postgres_user.arn
  postgres_password_ssm_arn   = aws_ssm_parameter.postgres_password.arn
  mongo_uri_ssm_arn           = aws_ssm_parameter.mongo_uri.arn
  mongo_database_ssm_arn      = aws_ssm_parameter.mongo_database.arn
  mongo_user_name_ssm_arn     = aws_ssm_parameter.mongo_user_name.arn
  mongo_password_ssm_arn      = aws_ssm_parameter.mongo_password.arn
  redis_endpoint_ssm_arn      = aws_ssm_parameter.redis_endpoint.arn
  redis_username_ssm_arn      = aws_ssm_parameter.redis_username.arn
  redis_password_ssm_arn      = aws_ssm_parameter.redis_password.arn
  frontend_url_ssm_arn        = aws_ssm_parameter.frontend_url.arn
  jwt_access_secret_ssm_arn   = aws_ssm_parameter.jwt_access_secret.arn
  jwt_refresh_secret_ssm_arn  = aws_ssm_parameter.jwt_refresh_secret.arn
  slack_client_id_ssm_arn     = aws_ssm_parameter.slack_client_id.arn
  slack_client_secret_ssm_arn = aws_ssm_parameter.slack_client_secret.arn
  slack_redirect_uri_ssm_arn  = aws_ssm_parameter.slack_redirect_uri.arn
  slack_bot_token_ssm_arn     = aws_ssm_parameter.slack_bot_token.arn
  slack_webhook_url_ssm_arn   = aws_ssm_parameter.slack_webhook_url.arn
  loki_uri_ssm_arn            = aws_ssm_parameter.loki_uri.arn

  # Auto Scaling
  api_min_count                     = var.api_min_count
  api_max_count                     = var.api_max_count
  cpu_target_value                  = var.cpu_target_value
  requests_per_target               = var.requests_per_target
  health_check_grace_period_seconds = var.health_check_grace_period_seconds
}

# Cloudflare (Worker, DNS, Page Rules)
module "cloudflare" {
  source                = "./modules/cloudflare"
  project_name          = var.project_name
  cloudflare_zone_id    = var.cloudflare_zone_id
  cloudflare_account_id = var.cloudflare_account_id
  domain_name           = var.domain_name
  frontend_url          = module.s3_frontend.website_url
  backend_dns_name      = module.alb.alb_dns_name
}

# =============================================================================
# SSM Parameter Store (Secrets - kept in root for environment-specific config)
# =============================================================================

# PostgreSQL
resource "aws_ssm_parameter" "postgres_host" {
  name  = "/bj-ranking/prod/POSTGRES_HOST"
  type  = "SecureString"
  value = var.postgres_host
}

resource "aws_ssm_parameter" "postgres_port" {
  name  = "/bj-ranking/prod/POSTGRES_PORT"
  type  = "String"
  value = var.postgres_port
}

resource "aws_ssm_parameter" "postgres_database" {
  name  = "/bj-ranking/prod/POSTGRES_DATABASE"
  type  = "SecureString"
  value = var.postgres_database
}

resource "aws_ssm_parameter" "postgres_user" {
  name  = "/bj-ranking/prod/POSTGRES_USER"
  type  = "SecureString"
  value = var.postgres_user
}

resource "aws_ssm_parameter" "postgres_password" {
  name  = "/bj-ranking/prod/POSTGRES_PASSWORD"
  type  = "SecureString"
  value = var.postgres_password
}

# MongoDB
resource "aws_ssm_parameter" "mongo_uri" {
  name  = "/bj-ranking/prod/MONGO_URI"
  type  = "SecureString"
  value = var.mongo_uri
}

resource "aws_ssm_parameter" "mongo_database" {
  name  = "/bj-ranking/prod/MONGO_DATABASE"
  type  = "String"
  value = var.mongo_database
}

resource "aws_ssm_parameter" "mongo_user_name" {
  name  = "/bj-ranking/prod/MONGO_USER_NAME"
  type  = "SecureString"
  value = var.mongo_user_name
}

resource "aws_ssm_parameter" "mongo_password" {
  name  = "/bj-ranking/prod/MONGO_PASSWORD"
  type  = "SecureString"
  value = var.mongo_password
}

# Redis
resource "aws_ssm_parameter" "redis_endpoint" {
  name  = "/bj-ranking/prod/REDIS_ENDPOINT"
  type  = "SecureString"
  value = var.redis_endpoint
}

resource "aws_ssm_parameter" "redis_username" {
  name  = "/bj-ranking/prod/REDIS_USERNAME"
  type  = "SecureString"
  value = var.redis_username
}

resource "aws_ssm_parameter" "redis_password" {
  name  = "/bj-ranking/prod/REDIS_PASSWORD"
  type  = "SecureString"
  value = var.redis_password
}

# Frontend URL (CORS)
resource "aws_ssm_parameter" "frontend_url" {
  name  = "/bj-ranking/prod/FRONTEND_URL"
  type  = "String"
  value = "https://${var.domain_name}"
}

# JWT
resource "aws_ssm_parameter" "jwt_access_secret" {
  name  = "/bj-ranking/prod/DEV_ACCESS_SECRET"
  type  = "SecureString"
  value = var.jwt_access_secret
}

resource "aws_ssm_parameter" "jwt_refresh_secret" {
  name  = "/bj-ranking/prod/DEV_REFRESH_SECRET"
  type  = "SecureString"
  value = var.jwt_refresh_secret
}

# Slack
resource "aws_ssm_parameter" "slack_client_id" {
  name  = "/bj-ranking/prod/SLACK_CLIENT_ID"
  type  = "SecureString"
  value = var.slack_client_id
}

resource "aws_ssm_parameter" "slack_client_secret" {
  name  = "/bj-ranking/prod/SLACK_CLIENT_SECRET"
  type  = "SecureString"
  value = var.slack_client_secret
}

resource "aws_ssm_parameter" "slack_redirect_uri" {
  name  = "/bj-ranking/prod/SLACK_REDIRECT_URI"
  type  = "String"
  value = var.slack_redirect_uri
}

resource "aws_ssm_parameter" "slack_bot_token" {
  name  = "/bj-ranking/prod/SLACK_BOT_TOKEN"
  type  = "SecureString"
  value = var.slack_bot_token
}

resource "aws_ssm_parameter" "slack_webhook_url" {
  name  = "/bj-ranking/prod/SLACK_WEBHOOK_URL"
  type  = "SecureString"
  value = var.slack_webhook_url
}

# Loki
resource "aws_ssm_parameter" "loki_uri" {
  name  = "/bj-ranking/prod/LOKI_URI"
  type  = "String"
  value = var.loki_uri
}
