# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-cluster"
  }
}

# -----------------------------------------------------------------------------
# EC2 Infrastructure (for API service)
# -----------------------------------------------------------------------------

# Latest ECS-optimized Amazon Linux 2 AMI
data "aws_ssm_parameter" "ecs_ami" {
  name = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

# Launch Template for ECS EC2 instances
resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.project_name}-ecs-"
  image_id      = data.aws_ssm_parameter.ecs_ami.value
  instance_type = var.ec2_instance_type

  iam_instance_profile {
    name = var.ecs_instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [var.ecs_security_group_id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    echo "ECS_CLUSTER=${aws_ecs_cluster.main.name}" >> /etc/ecs/ecs.config
    echo "ECS_ENABLE_CONTAINER_METADATA=true" >> /etc/ecs/ecs.config
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-ecs-instance"
    }
  }

  tags = {
    Name = "${var.project_name}-launch-template"
  }
}

# Auto Scaling Group for ECS EC2 instances
resource "aws_autoscaling_group" "ecs" {
  name                = "${var.project_name}-ecs-asg"
  vpc_zone_identifier = var.subnet_ids
  min_size            = var.ec2_min_count
  max_size            = var.ec2_max_count
  desired_capacity    = var.ec2_desired_count

  # Mixed instances policy: On-Demand base + Spot for additional capacity
  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs.id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.small"
      }
      override {
        instance_type = "t3.micro"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 1  # Always 1 On-Demand
      on_demand_percentage_above_base_capacity = 0  # Rest are Spot
      spot_allocation_strategy                 = "lowest-price"
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-ecs-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Capacity Provider
resource "aws_ecs_capacity_provider" "main" {
  name = "${var.project_name}-cp"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.ecs.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      maximum_scaling_step_size = 2
      minimum_scaling_step_size = 1
      status                    = "ENABLED"
      target_capacity           = 100
    }
  }

  tags = {
    Name = "${var.project_name}-capacity-provider"
  }
}

# Associate Capacity Provider with Cluster
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = [aws_ecs_capacity_provider.main.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.main.name
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
# API Task Definition (EC2 launch type with bridge network mode)
# -----------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-api"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.execution_role_arn

  container_definitions = jsonencode([{
    name      = "api-container"
    image     = var.api_image
    essential = true
    cpu       = var.api_cpu
    memory    = var.api_memory

    portMappings = [{
      containerPort = var.app_port
      hostPort      = 0  # Dynamic port mapping for bridge mode
      protocol      = "tcp"
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
      { name = "SLACK_BOT_TOKEN", valueFrom = var.slack_bot_token_ssm_arn },
      # Loki
      { name = "LOKI_URI", valueFrom = var.loki_uri_ssm_arn }
    ]

    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.api_spring_profile },
      { name = "TZ", value = "Asia/Seoul" }
    ]

    # Use json-file driver for Promtail to collect logs
    logConfiguration = {
      logDriver = "json-file"
      options = {
        "max-size" = "100m"
        "max-file" = "5"
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
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([{
    name      = "worker-container"
    image     = var.worker_image
    essential = true

    secrets = [
      # MongoDB
      { name = "MONGO_URI", valueFrom = var.mongo_uri_ssm_arn },
      { name = "MONGO_DATABASE", valueFrom = var.mongo_database_ssm_arn },
      { name = "MONGO_USER_NAME", valueFrom = var.mongo_user_name_ssm_arn },
      { name = "MONGO_PASSWORD", valueFrom = var.mongo_password_ssm_arn },
      # PostgreSQL
      { name = "POSTGRES_HOST", valueFrom = var.postgres_host_ssm_arn },
      { name = "POSTGRES_PORT", valueFrom = var.postgres_port_ssm_arn },
      { name = "POSTGRES_DATABASE", valueFrom = var.postgres_database_ssm_arn },
      { name = "POSTGRES_USER", valueFrom = var.postgres_user_ssm_arn },
      { name = "POSTGRES_PASSWORD", valueFrom = var.postgres_password_ssm_arn },
      # Slack
      { name = "SLACK_WEBHOOK_URL", valueFrom = var.slack_webhook_url_ssm_arn }
    ]

    environment = [
      { name = "SPRING_PROFILES_ACTIVE", value = var.worker_spring_profile }
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
# ECS Service (API - Always-on, EC2 launch type)
# -----------------------------------------------------------------------------
resource "aws_ecs_service" "api" {
  name            = "${var.project_name}-api-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_min_count

  # Use Capacity Provider instead of launch_type
  capacity_provider_strategy {
    capacity_provider = aws_ecs_capacity_provider.main.name
    weight            = 100
    base              = 1
  }

  # Wait before starting health checks (Spring Boot startup ~90s)
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  # Deployment configuration (EC2 can be more flexible)
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  # Circuit breaker: auto rollback on deployment failure
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  # No network_configuration for bridge mode

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "api-container"
    container_port   = var.app_port
  }

  # Spread tasks across AZs
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }

  lifecycle {
    ignore_changes = [desired_count] # Let auto scaling manage this
  }

  tags = {
    Name = "${var.project_name}-api-svc"
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
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

  # Pass scheduled time to container as command argument
  input_transformer {
    input_paths = {
      scheduled_time = "$.time"
    }
    input_template = <<-EOF
      {
        "containerOverrides": [
          {
            "name": "worker-container",
            "command": ["<scheduled_time>"]
          }
        ]
      }
    EOF
  }

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

# -----------------------------------------------------------------------------
# EventBridge Rule for Batch Finished Event (Logging)
# -----------------------------------------------------------------------------

# CloudWatch Log Group for Batch Events
resource "aws_cloudwatch_log_group" "batch_events" {
  name              = "/aws/events/${var.project_name}-batch"
  retention_in_days = var.log_retention_days

  tags = {
    Name = "${var.project_name}-batch-events-logs"
  }
}

# EventBridge Rule - Batch Finished Event Pattern
resource "aws_cloudwatch_event_rule" "batch_finished" {
  name        = "${var.project_name}-batch-finished"
  description = "Capture Batch Finished events from slackJudge application"

  event_pattern = jsonencode({
    source      = ["com.slackJudge.batch"]
    detail-type = ["Batch Finished"]
  })

  tags = {
    Name = "${var.project_name}-batch-finished"
  }
}

# CloudWatch Logs Resource Policy for EventBridge
resource "aws_cloudwatch_log_resource_policy" "batch_events" {
  policy_name = "${var.project_name}-batch-events-policy"

  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.batch_events.arn}:*"
    }]
  })
}

# EventBridge Target - CloudWatch Logs
resource "aws_cloudwatch_event_target" "batch_finished_logs" {
  rule      = aws_cloudwatch_event_rule.batch_finished.name
  target_id = "${var.project_name}-batch-finished-logs"
  arn       = aws_cloudwatch_log_group.batch_events.arn
}

# -----------------------------------------------------------------------------
# Promtail Daemon Service (Log collection for Loki)
# -----------------------------------------------------------------------------

# Promtail Task Definition
resource "aws_ecs_task_definition" "promtail" {
  family                   = "${var.project_name}-promtail"
  network_mode             = "bridge"
  requires_compatibilities = ["EC2"]
  execution_role_arn       = var.execution_role_arn

  # Mount Docker socket and container logs directory
  volume {
    name      = "docker-sock"
    host_path = "/var/run/docker.sock"
  }

  volume {
    name      = "containers"
    host_path = "/var/lib/docker/containers"
  }

  container_definitions = jsonencode([{
    name      = "promtail"
    image     = var.promtail_image
    essential = true
    cpu       = 128
    memory    = 256

    environment = [
      { name = "LOKI_URL", value = var.loki_url }
    ]

    mountPoints = [
      {
        sourceVolume  = "docker-sock"
        containerPath = "/var/run/docker.sock"
        readOnly      = true
      },
      {
        sourceVolume  = "containers"
        containerPath = "/var/lib/docker/containers"
        readOnly      = true
      }
    ]

    # Promtail logs go to CloudWatch for debugging
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "promtail"
      }
    }
  }])

  tags = {
    Name = "${var.project_name}-promtail"
  }
}

# Promtail Daemon Service (runs on every EC2 instance)
resource "aws_ecs_service" "promtail" {
  name                = "${var.project_name}-promtail-daemon"
  cluster             = aws_ecs_cluster.main.id
  task_definition     = aws_ecs_task_definition.promtail.arn
  scheduling_strategy = "DAEMON"
  launch_type         = "EC2"  # DAEMON requires explicit launch_type, not capacity_provider_strategy

  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 100

  tags = {
    Name = "${var.project_name}-promtail-daemon"
  }

  depends_on = [aws_ecs_cluster_capacity_providers.main]
}
