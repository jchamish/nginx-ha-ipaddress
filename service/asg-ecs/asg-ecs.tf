variable "env_val" {}
variable "product_name" {}

# alb
variable "tg_arn" {}

# ecs
variable "ecs_desired" {}
variable "ecs_min" {}
variable "ecs_max" {}
variable "ecs_iam_role" {}
variable "container_name" {}

# ec2
variable "ec2_instance_type" {}
variable "ec2_desired" {}
variable "ec2_min" {}
variable "ec2_max" {}
variable "instance_role" {}
variable "instance_role_profile" {}

# network and lc
variable "vpc_id" {}
variable "sg_id" {}
variable "subnets_public" {}
variable "amiid_linux" {}

# lt ec2
module "lc" {
  source = "../lc"
  env_val = var.env_val
  product_name = var.product_name
  amiid = var.amiid_linux
  iamrole = var.instance_role_profile.name
  instance_type = var.ec2_instance_type
  lc_sg = [var.sg_id]
} 

# create ecr
resource "aws_ecr_repository" "nginx_ecr" {
  name                 = "nginx-ipaddress"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# task def for container
data "template_file" "nginx_container" {
  template = "${file("./asg-ecs/task-definition/nginx-container.tpl.json")}"
  vars = {
    image = "${aws_ecr_repository.nginx_ecr.repository_url}:latest"
    container_name = var.container_name
    env = var.env_val
  }
}

# create task def
resource "aws_ecs_task_definition" "nginx_taskdef" {
  family = "nginx-task-${var.env_val}"
  container_definitions = data.template_file.nginx_container.rendered

  network_mode = "bridge"
  requires_compatibilities = ["EC2"]

  
  volume {
    name      = "shared-website"
    host_path = "/home/ec2-user/website"
  }

}

resource "aws_ecs_cluster" "nginx_cluster" {
  name = "${var.product_name}-cluster-${var.env_val}"
  tags = {
      Application = var.product_name,
      Environment = var.env_val
  }
}


# ecs 
resource "aws_ecs_service" "nginx_ecs" {
  name            = "${var.product_name}-ecs-${var.env_val}"
  cluster         = aws_ecs_cluster.nginx_cluster.arn
  task_definition = aws_ecs_task_definition.nginx_taskdef.arn
  desired_count   = var.ecs_desired
  iam_role        = var.ecs_iam_role

  health_check_grace_period_seconds = 100

  load_balancer {
    target_group_arn = var.tg_arn
    container_name = var.container_name
    container_port = 80
  }

  lifecycle {
    ignore_changes = [
      desired_count
    ]
  }
}

resource "aws_appautoscaling_target" "ecs_scaling" {
  max_capacity       = var.ecs_max
  min_capacity       = var.ecs_min
  resource_id        = "service/${aws_ecs_cluster.nginx_cluster.name}/${aws_ecs_service.nginx_ecs.name}"
  role_arn           = var.instance_role.arn
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "ecs_policy_scaleup" {
  name                    = "${var.product_name}-ECS-ScaleupPolicy-${var.env_val}"
  resource_id             = "service/${aws_ecs_cluster.nginx_cluster.name}/${aws_ecs_service.nginx_ecs.name}"
  scalable_dimension      = "ecs:service:DesiredCount"
  service_namespace       = "ecs"

  step_scaling_policy_configuration {
    adjustment_type         = "ChangeInCapacity"
    cooldown                = 600
    metric_aggregation_type = "Average"

    step_adjustment {
      metric_interval_lower_bound = 0
      scaling_adjustment          = 1
    }
  }
}

# ec2
resource "aws_autoscaling_group" "nginx_ecs_asg" {
    name = "${var.product_name}-ecs-${var.env_val}-asg"
    launch_template {
      id = module.lc.launch_template_id
      version = "$Latest"
    }
    min_size = var.ec2_min
    max_size = var.ec2_max
    default_cooldown = 750
    health_check_grace_period = 600
    health_check_type = "EC2"
    desired_capacity = var.ec2_desired
    termination_policies = ["OldestInstance"]
    vpc_zone_identifier = var.subnets_public

    enabled_metrics = [
      "GroupMinSize",
      "GroupMaxSize",
      "GroupDesiredCapacity",
      "GroupInServiceInstances",
      "GroupPendingInstances"
    ]
    
    tag {
      key = "ecs_cluster_name"
      value = "${var.product_name}-cluster-${var.env_val}"
      propagate_at_launch = true
    }

    tag {
      key = "Name"
      value = "${var.env_val} - ${var.product_name}-ecs"
      propagate_at_launch = true
    }

    tag {
      key = "Environment"
      value = var.env_val
      propagate_at_launch = true
    }

    lifecycle {
      create_before_destroy = true
    }
}

# resource "aws_autoscaling_policy" "asg_scaleup" {
#     name = "ngnix-${var.env_val}-up-policy"
#     scaling_adjustment = 1
#     adjustment_type = "ChangeInCapacity"
#     cooldown = aws_autoscaling_group.nginx_ecs_asg.default_cooldown
#     autoscaling_group_name = aws_autoscaling_group.nginx_ecs_asg.name
# }

# resource "aws_autoscaling_policy" "asg_scaledown" {
#   name = "places-api-${var.env_val}_DownPolicy"
#   scaling_adjustment = -1
#   adjustment_type = "ChangeInCapacity"
#   cooldown = aws_autoscaling_group.nginx_ecs_asg.default_cooldown
#   autoscaling_group_name = aws_autoscaling_group.nginx_ecs_asg.name
# }

# resource "aws_cloudwatch_metric_alarm" "tg_highlatency_alarm" {
#     alarm_name = "${var.product_name}_tg_${var.env_val}_HLA"
#     namespace = "AWS/ApplicationELB"
#     comparison_operator = "GreaterThanOrEqualToThreshold"
#     metric_name = "TargetResponseTime"
#     threshold = "0.5"
#     statistic = "Average"
#     period = "60"
#     evaluation_periods = "5"
#     dimensions = {
#       LoadBalancer = var.albarn_suffix
#       TargetGroup = var.tgarn_suffix
#     }
#     alarm_actions = [aws_appautoscaling_policy.ecs_policy_scaleup.arn]
# }

# resource "aws_appautoscaling_policy" "ecs_policy_scaledown" {
#   name                    = "${var.product_name}-ecs-ScaleDownPolicy-${var.env_val}"
#   resource_id             = "service/${aws_ecs_cluster.nginx_cluster.name}/${aws_ecs_service.aws_ecs_service.name}"
#   scalable_dimension      = "ecs:service:DesiredCount"
#   service_namespace       = "ecs"

#   step_scaling_policy_configuration {
#     adjustment_type         = "ChangeInCapacity"
#     cooldown                = 600
#     metric_aggregation_type = "Average"

#     step_adjustment {
#       metric_interval_upper_bound = 0
#       scaling_adjustment          = -1
#     }
#   }
# }

# resource "aws_cloudwatch_metric_alarm" "tg_lowlatency_alarm" {
#     alarm_name = "${var.product}_tg_${var.env_val}_LowLatencyAlarm"
#     namespace = "AWS/ApplicationELB"
#     comparison_operator = "LessThanOrEqualToThreshold"
#     metric_name = "TargetResponseTime"
#     threshold = "0.15"
#     statistic = "Average"
#     period = "60"
#     evaluation_periods = "5"
#     dimensions = {
#       LoadBalancer = var.albarn_suffix
#       TargetGroup = var.tgarn_suffix
#     }
#     alarm_actions = [aws_appautoscaling_policy.ecs_policy_scaledown.arn]

#     tags = {
#       Application = var.product_name,
#       Environment = var.env_val
#     }
# }

# resource "aws_cloudwatch_metric_alarm" "cluster_highmemory_reservation_alarm" {
#     count = local.enable_asgscaling_alarms
#     alarm_name = "${var.product}_tg_${var.env_val}_HighMemoryReservationAlarm"
#     namespace = "AWS/ECS"
#     comparison_operator = "GreaterThanOrEqualToThreshold"
#     metric_name = "MemoryReservation"
#     threshold = "85"
#     statistic = "Average"
#     period = "60"
#     evaluation_periods = "5"
#     dimensions = {
#       ClusterName = aws_ecs_cluster.ng.name
#     }
#     alarm_actions = [aws_autoscaling_policy.asg_scaleup.arn]  
#     depends_on = ["aws_autoscaling_policy.asg_scaleup"]

#     tags = {
#       Application = var.product,
#       Environment = var.env_val
#     }
# }

# resource "aws_cloudwatch_metric_alarm" "cluster_lowmemory_reservation_alarm" {
#     count = "50"
#     alarm_name = "${var.product}_TG_${var.env_val}_LowMemoryReservationAlarm"
#     namespace = "AWS/ECS"
#     comparison_operator = "LessThanOrEqualToThreshold"
#     metric_name = "MemoryReservation"
#     threshold = "50"
#     statistic = "Average"
#     period = "60"
#     evaluation_periods = "5"
#     dimensions = {
#       ClusterName = aws_ecs_cluster.nginx_cluster.name
#     }
#     alarm_actions = [aws_autoscaling_policy.asg_scaledown.arn]
#     depends_on = ["aws_autoscaling_policy.asg_scaledown"]

#     tags = {
#       Application = var.product_name,
#       Environment = var.env_val
#     }
# }

# resource "aws_autoscaling_notification" "app_scaledown" {
#     depends_on = ["aws_autoscaling_group.nginx_ecs_asg"]
#     group_names = [
#       aws_autoscaling_group.nginx_ecs_asg.name,
#       aws_autoscaling_group.nginx_ecs_asg.name,
#     ]
#     notifications  = [
#       "autoscaling:EC2_INSTANCE_TERMINATE",
#       "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
#     ]
# }

# resource "aws_autoscaling_notification" "app_scaleup" {
#     depends_on = ["aws_autoscaling_group.nginx_ecs_asg"]
#     group_names = [
#       aws_autoscaling_group.nginx_cluster.name,
#       aws_autoscaling_group.nginx_ecs_asg.name,
#     ]
#     notifications  = [
#       "autoscaling:EC2_INSTANCE_LAUNCH",
#       "autoscaling:EC2_INSTANCE_LAUNCH_ERROR"
#     ]
# }
