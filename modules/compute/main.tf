#----------------------------------------------------------
# Web Tier Launch Template and Auto Scaling Group
#----------------------------------------------------------

resource "aws_launch_template" "web-tier" {
  name_prefix            = "${var.project_name}-webtier"
  image_id               = var.ami_id #data.aws_ami.golden.id               
  instance_type          = var.web_instance_type
  vpc_security_group_ids = [var.web_sg_id]

  user_data = base64encode(templatefile("${path.module}/web_user_data.sh", {
    internal_alb_dns = var.internal_alb_dns # was aws_lb.internal.dns_name
    app_port         = var.app_port
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-tier"
      Tier = "web"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.project_name}-web-asg"
  vpc_zone_identifier       = var.public_subnet_ids          # was aws_subnet.public[*].id
  target_group_arns         = [var.webtier_target_group_arn] # was [aws_lb_target_group.web.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 600

  min_size                  = var.web_asg_config.min_size
  max_size                  = var.web_asg_config.max_size
  desired_capacity          = var.web_asg_config.desired_capacity
  wait_for_capacity_timeout = "0"

  launch_template {
    id      = aws_launch_template.web-tier.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-web-tier"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "web_cpu" {
  name                   = "${var.project_name}-web-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

#----------------------------------------------------------
# App Tier Launch Template and Auto Scaling Group
#----------------------------------------------------------
resource "aws_launch_template" "app-tier" {
  name_prefix            = "${var.project_name}-apptier"
  image_id               = var.ami_id #data.aws_ami.golden.id 
  instance_type          = var.web_instance_type
  vpc_security_group_ids = [var.app_sg_id]

  user_data = base64encode(templatefile("${path.module}/app_user_data.sh", {
    app_port    = var.app_port
    db_endpoint = var.db_endpoint
    db_port     = var.db_port
    db_name     = var.db_name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-app-tier"
      Tier = "app"
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "app" {
  name                      = "${var.project_name}-app-asg"
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [var.apptier_target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size                  = var.web_asg_config.min_size
  max_size                  = var.web_asg_config.max_size
  desired_capacity          = var.web_asg_config.desired_capacity
  wait_for_capacity_timeout = "0"

  launch_template {
    id      = aws_launch_template.app-tier.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app-tier"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "app_cpu" {
  name                   = "${var.project_name}-app-cpu-policy"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

#----------------------------------------------------------
# Golden AMI
#----------------------------------------------------------
data "aws_ami" "golden" {
  most_recent = true
  owners      = ["self"] # AMIs your account built

  filter {
    name   = "tag:Name"
    values = ["${var.project_name}-golden-ami"]
  }
}