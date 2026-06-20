# ---------------------------------------------------------------------------
# Public (internet-facing) ALB  ->  Web tier
# ---------------------------------------------------------------------------
resource "aws_lb" "public" {
  name               = "${var.project_name}-public-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.public_alb_sg_id] # was aws_security_group.public_alb.id
  subnets            = var.public_subnet_ids  # was aws_subnet.public[*].id

  tags = { Name = "${var.project_name}-webtier-alb" }
}

resource "aws_lb_target_group" "webtier" {
  name     = "${var.project_name}-webtier-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id # was aws_vpc.main.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project_name}-webtier-tg" }
}

resource "aws_lb_listener" "public_http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webtier.arn
  }
}

# ---------------------------------------------------------------------------
# Internal ALB  ->  App tier
# ---------------------------------------------------------------------------
resource "aws_lb" "internal" {
  name               = "${var.project_name}-internal-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.internal_alb_sg_id] # was aws_security_group.internal_alb.id
  subnets            = var.private_subnet_ids   # was aws_subnet.private[*].id

  tags = { Name = "${var.project_name}-apptier-alb" }
}

resource "aws_lb_target_group" "apptier" {
  name     = "${var.project_name}-apptier-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id # was aws_vpc.main.id

  health_check {
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = { Name = "${var.project_name}-apptier-tg" }
}

resource "aws_lb_listener" "internal_http" {
  load_balancer_arn = aws_lb.internal.arn
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.apptier.arn
  }
}