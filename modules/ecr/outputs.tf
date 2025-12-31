output "api_repository_url" {
  description = "API ECR repository URL"
  value       = aws_ecr_repository.api.repository_url
}

output "api_repository_arn" {
  description = "API ECR repository ARN"
  value       = aws_ecr_repository.api.arn
}

output "worker_repository_url" {
  description = "Worker ECR repository URL"
  value       = aws_ecr_repository.worker.repository_url
}

output "worker_repository_arn" {
  description = "Worker ECR repository ARN"
  value       = aws_ecr_repository.worker.arn
}

output "promtail_repository_url" {
  description = "Promtail ECR repository URL"
  value       = aws_ecr_repository.promtail.repository_url
}

output "promtail_repository_arn" {
  description = "Promtail ECR repository ARN"
  value       = aws_ecr_repository.promtail.arn
}
