output "ecs_execution_role_arn" {
  description = "ECS task execution role ARN"
  value       = aws_iam_role.ecs_execution.arn
}

output "ecs_execution_role_name" {
  description = "ECS task execution role name"
  value       = aws_iam_role.ecs_execution.name
}

output "eventbridge_role_arn" {
  description = "EventBridge role ARN for scheduled tasks"
  value       = aws_iam_role.eventbridge.arn
}

output "ecs_task_role_arn" {
  description = "ECS task role ARN for application-level AWS API calls"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_instance_profile_name" {
  description = "ECS EC2 instance profile name"
  value       = aws_iam_instance_profile.ecs_instance.name
}

output "ecs_instance_profile_arn" {
  description = "ECS EC2 instance profile ARN"
  value       = aws_iam_instance_profile.ecs_instance.arn
}

output "ecs_instance_role_arn" {
  description = "ECS EC2 instance role ARN"
  value       = aws_iam_role.ecs_instance.arn
}
