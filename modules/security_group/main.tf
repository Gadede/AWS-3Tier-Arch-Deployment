# ---------------------------------------------------------------------------
# Public ALB security group  (internet-facing)
# ---------------------------------------------------------------------------
resource "aws_security_group" "public_alb" {
  name        = "${var.project_name}-public-alb-sg"
  description = "Allow HTTP/HTTPS from the internet to the public ALB."
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-webtier-alb-sg"
  }
}

# ---------------------------------------------------------------------------
# Web tier security group  (only the public ALB may reach it)
# ---------------------------------------------------------------------------
resource "aws_security_group" "webtier-sg" {
  name        = "${var.project_name}-webtier-sg"
  description = "Allow HTTP from the public ALB to the web tier."
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from public ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.public_alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-webtier-sg"
  }
}

# ---------------------------------------------------------------------------
# Internal ALB security group  (only the web tier may reach it)
# ---------------------------------------------------------------------------
resource "aws_security_group" "internal_alb" {
  name        = "${var.project_name}-internal-alb-sg"
  description = "Allow the app port from the web tier to the internal ALB."
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from web tier"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.webtier-sg.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-apptier-alb-sg"
  }
}

# ---------------------------------------------------------------------------
# App tier security group  (only the internal ALB may reach it)
# ---------------------------------------------------------------------------
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Allow the app port from the internal ALB to the app tier."
  vpc_id      = var.vpc_id

  ingress {
    description     = "App port from internal ALB"
    from_port       = var.app_port
    to_port         = var.app_port
    protocol        = "tcp"
    security_groups = [aws_security_group.internal_alb.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-apptier-sg"
  }
}

# ---------------------------------------------------------------------------
# Database security group  (only the app tier may reach it)
# ---------------------------------------------------------------------------
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Allow the database port from the app tier only."
  vpc_id      = var.vpc_id

  ingress {
    description     = "DB port from app tier"
    from_port       = var.db_port
    to_port         = var.db_port
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}
