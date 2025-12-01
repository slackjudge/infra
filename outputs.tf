# =============================================================================
# AWS Resource URLs
# =============================================================================
output "frontend_s3_url" {
  description = "S3 static website endpoint"
  value       = module.s3_frontend.website_url
}

output "backend_alb_url" {
  description = "ALB DNS endpoint"
  value       = "http://${module.alb.alb_dns_name}"
}

output "s3_bucket_name" {
  description = "Frontend S3 bucket name (for deployment)"
  value       = module.s3_frontend.bucket_name
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "api_ecr_repository_url" {
  description = "API ECR repository URL"
  value       = module.ecr.api_repository_url
}

output "worker_ecr_repository_url" {
  description = "Worker ECR repository URL"
  value       = module.ecr.worker_repository_url
}

# =============================================================================
# Cloudflare
# =============================================================================
output "site_url" {
  description = "Final service URL (HTTPS)"
  value       = module.cloudflare.site_url
}
