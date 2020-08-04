variable "product_name" {}
variable "env_val" {}
variable "alb_sg" {}
variable "subnets_external" {}
variable "vpc_id" {}

resource "aws_alb" "alb_nginx" {
  name            = "${var.product_name}-alb"
  internal        = false
  security_groups = [var.alb_sg]
  subnets         = var.subnets_external

  enable_deletion_protection = true
  idle_timeout = 300
  ip_address_type = "dualstack"

  tags = {
    Environment = var.env_val
  }
}

resource "aws_alb_target_group" "nginx_tg_http" {
  name     = "${var.product_name}-tg-http"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id
  deregistration_delay = 60
  health_check {
    protocol = "HTTP"
    interval = 15
    timeout = 14
    path = "/"
    healthy_threshold = 2
    unhealthy_threshold = 5
  }
}


resource "aws_alb_listener" "https-listener" {
  load_balancer_arn = aws_alb.alb_nginx.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"

  default_action {
    target_group_arn = aws_alb_target_group.nginx_tg_http.arn
    type             = "forward"
  }
}

resource "aws_alb_listener" "http-listener" {
  load_balancer_arn = aws_alb.alb_nginx.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.nginx_tg_http.arn
    type             = "forward"
  }
}

# using arn for other fields

output "tg_arn" {
  value = aws_alb_target_group.nginx_tg_http.arn
}

output "alb_arn_suffic" {
  value = aws_alb.alb_nginx.arn_suffix
}

output "tg_arn_suffix" {
  value = aws_alb_target_group.nginx_tg_http.arn_suffix
}
