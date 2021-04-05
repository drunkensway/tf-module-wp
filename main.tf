terraform {
  backend "s3" {
    bucket = "blog-app-2021-remote-state"
    region = "us-east-2"
    key = "modules/services/terraform.tfstate"

    dynamodb_table = "blog-app-s3-locks"
    encrypt = true
  }
}

locals {
    http_port = 80
    any_port = 0
    any_protocol = "-1"
    tcp_protocol = "tcp"
    all_ips = ["0.0.0.0/0"]
}

data "template_file" "user_data" {
    template = file("${path.module}/user-data.sh")
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

resource "aws_launch_configuration" "launch_config" {
    image_id = "ami-0f04d6eabd235a010"
    instance_type = var.instance_type
    iam_instance_profile = "ec2_s3_profile"
    security_groups = [aws_security_group.instance.id]
    user_data = data.template_file.user_data.rendered
    key_name = "wpinfra"

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_security_group" "instance" {
    name = "${var.cluster_name}-instance-sg"
}

resource "aws_security_group_rule" "allow_in_alb_traffic" {
    type = "ingress"
    security_group_id = aws_security_group.instance.id

    from_port = var.server_port
    to_port = var.server_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips   
}

resource "aws_security_group_rule" "allow_all_outbound_instance" {
    type = "egress"
    security_group_id = aws_security_group.instance.id

    cidr_blocks = local.all_ips
    from_port = local.any_port
    protocol = local.any_protocol
    to_port = local.any_port
}

resource "aws_security_group" "alb" {
    name = "${var.cluster_name}-alb"
}

resource "aws_security_group_rule" "allow_http_inbound" {
    type = "ingress"
    security_group_id = aws_security_group.alb.id

    from_port = local.http_port
    to_port = local.http_port
    protocol = local.tcp_protocol
    cidr_blocks = local.all_ips
}

resource "aws_security_group_rule" "allow_all_outbound" {
    type = "egress"
    security_group_id = aws_security_group.alb.id

    cidr_blocks = local.all_ips
    from_port = local.any_port
    protocol = local.any_protocol
    to_port = local.any_port
}

resource "aws_autoscaling_group" "asg" {
    launch_configuration = aws_launch_configuration.launch_config.name
    vpc_zone_identifier = data.aws_subnet_ids.default.ids

    target_group_arns = [aws_lb_target_group.lb_target_group.arn]
    health_check_type = "ELB"

    min_size = var.min_size
    max_size = var.max_size

    tag {
        key = "Name"
        value = var.cluster_name
        propagate_at_launch = true
    }
}

resource "aws_lb" "alb" {
    name = "${var.cluster_name}-alb"
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.default.ids
    security_groups = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.alb.arn
    port = local.http_port
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
          content_type = "text/plain"
          message_body = "404: page not found"
          status_code = 404
      }
    }
}

resource "aws_lb_target_group" "lb_target_group" {
    name = "tf-tg"
    port = var.server_port
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200,301,302"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    } 
}

resource "aws_lb_listener_rule" "lb_listener_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority = 100

  condition {
      path_pattern {
          values = ["*"]
      }
  }

  action {
      type = "forward"
      target_group_arn = aws_lb_target_group.lb_target_group.arn
  }
}
