# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-ecs-logs"
  }
}

# -----------------------------------------------------------------------------
# API Task Definition (Always-on Service)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([{
    name      = "api-container"
    image     = var.api_image
    essential = true

    portMappings = [{
      containerPort = var.app_port
      hostPort      = var.app_port
    }]

    secrets = [
      # PostgreSQL
      { name = "POSTGRES_HOST", valueFrom = var.postgres_host_ssm_arn },
      { name = "POSTGRES_PORT", valueFrom = var.postgres_port_ssm_arn },
      { name = "POSTGRES_DATABASE", valueFrom = var.postgres_database_ssm_arn },
      { name = "POSTGRES_USER", valueFrom = var.postgres_user_ssm_arn },
      { name = "POSTGRES_PASSWORD", valueFrom = var.postgres_password_ssm_arn },
      # MongoDB
      { name = "MONGO_URI", valueFrom = var.mongo_uri_ssm_arn },
      { name = "MONGO_DATABASE", valueFrom = var.mongo_database_ssm_arn },
      { name = "MONGO_PASSWORD", valueFrom = var.mongo_password_ssm_arn },
      # Redis
      { name = "REDIS_ENDPOINT", valueFrom = var.redis_endpoint_ssm_arn },
      { name = "REDIS_USERNAME", valueFrom = var.redis_username_ssm_arn },
      { name = "REDIS_PASSWORD", valueFrom = var.redis_password_ssm_arn },
      # Frontend URL (CORS)
      { name = "FRONTEND_URL", valueFrom = var.frontend_url_ssm_arn },
      # JWT
      { name = "DEV_ACCESS_SECRET", valueFrom = var.jwt_access_secret_ssm_arn },
      { name = "DEV_REFRESH_SECRET", valueFrom = var.jwt_refresh_secret_ssm_arn },
      # Slack
      { name = "SLACK_CLIENT_ID", valueFrom = var.slack_client_id_ssm_arn },
      { name = "SLACK_CLIENT_SECRET", valueFrom = var.slack_client_secret_ssm_arn },
      { name = "SLACK_REDIRECT_URI", valueFrom = var.slack_redirect_uri_ssm_arn },
      { name = "SLACK_BOT_TOKEN", valueFrom = var.slack_bot_token_ssm_arn }
    ]

    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.spring_profile }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "api"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-api"
  }
}

# -----------------------------------------------------------------------------
# Worker Task Definition (Batch/Scheduled)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.project_name}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([{
    name      = "worker-container"
    image     = var.worker_image
    essential = true

    secrets = [
      # PostgreSQL
      { name = "POSTGRES_HOST", valueFrom = var.postgres_host_ssm_arn },
      { name = "POSTGRES_PORT", valueFrom = var.postgres_port_ssm_arn },
      { name = "POSTGRES_DATABASE", valueFrom = var.postgres_database_ssm_arn },
      { name = "POSTGRES_USER", valueFrom = var.postgres_user_ssm_arn },
      { name = "POSTGRES_PASSWORD", valueFrom = var.postgres_password_ssm_arn },
      # MongoDB
      { name = "MONGO_URI", valueFrom = var.mongo_uri_ssm_arn },
      { name = "MONGO_DATABASE", valueFrom = var.mongo_database_ssm_arn },
      { name = "MONGO_PASSWORD", valueFrom = var.mongo_password_ssm_arn },
      # Redis
      { name = "REDIS_ENDPOINT", valueFrom = var.redis_endpoint_ssm_arn },
      { name = "REDIS_USERNAME", valueFrom = var.redis_username_ssm_arn },
      { name = "REDIS_PASSWORD", valueFrom = var.redis_password_ssm_arn },
      # Slack
      { name = "SLACK_WEBHOOK_URL", valueFrom = var.slack_webhook_url_ssm_arn }
    ]

    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.spring_profile }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "worker"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-worker"
  }
}

# -----------------------------------------------------------------------------
# ECS Service (API - Always-on)
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_min_count
  launch_type     = "FARGATE"

  # Wait before starting health checks (Spring Boot startup ~90s)
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Deployment configuration (zero-downtime rolling update)
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  # Circuit breaker: auto rollback on deployment failure
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = true # Required for public subnet (no NAT Gateway)
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api-container"
    container_port   = var.app_port
  }

  lifecycle {
    ignore_changes = [desired_count] # Let auto scaling manage this
  }

  tags = {
    Name = "${var.project_name}-api-svc"
  }
}

# -----------------------------------------------------------------------------
# Auto Scaling
# -----------------------------------------------------------------------------
resource "aws_appautoscaling_target" "api" {
  max_capacity       = var.api_max_count
  min_capacity       = var.api_min_count
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.api.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# CPU-based scaling policy
resource "aws_appautoscaling_policy" "api_cpu" {
  name               = "${var.project_name}-api-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value       = var.cpu_target_value
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# ALB Request Count scaling policy
resource "aws_appautoscaling_policy" "api_requests" {
  name               = "${var.project_name}-api-request-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.api.resource_id
  scalable_dimension = aws_appautoscaling_target.api.scalable_dimension
  service_namespace  = aws_appautoscaling_target.api.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${var.alb_arn_suffix}/${var.target_group_arn_suffix}"
    }
    target_value       = var.requests_per_target
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}

# -----------------------------------------------------------------------------
# EventBridge (Worker Scheduling)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_event_rule" "worker_schedule" {
  name                = "${var.project_name}-worker-schedule"
  description         = "Run Worker task on schedule"
  schedule_expression = var.worker_schedule

  tags = {
    Name = "${var.project_name}-worker-schedule"
  }
}

resource "aws_cloudwatch_event_target" "worker" {
  rule      = aws_cloudwatch_event_rule.worker_schedule.name
  target_id = "${var.project_name}-worker-job"
  arn       = aws_ecs_cluster.main.arn
  role_arn  = var.eventbridge_role_arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.worker.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = [var.ecs_security_group_id]
      assign_public_ip = true
    }
  }
}
