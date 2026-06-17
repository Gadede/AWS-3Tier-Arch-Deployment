variable "project_name" {
  description = "The name of the project, used for tagging resources"
  type        = string
  default     = "aws-3-tier-app"
}

variable "web_instance_type" {
  description = "The instance type for the web tier EC2 instances"
  type        = string
  default     = "t3.micro"
}

variable "app_port" {
  description = "The port on which the application listens (for internal ALB target group)"
  type        = number
  default     = 80
}

variable "web_asg_config" {
  description = "Configuration for the web tier Auto Scaling Group"
  type = object({
    desired_capacity = number
    max_size        = number
    min_size        = number
  })
  default = {
    desired_capacity = 2
    max_size        = 2
    min_size        = 2
  }
}

variable "ami_id" {
  description = "AMI ID for the web tier instances"
  type        = string
}

# variable "vpc_id" {
#   description = "VPC ID"
#   type        = string
# }

variable "public_subnet_ids" {
  description = "Public subnets for the web tier ASG"
  type        = list(string)
}

variable "web_sg_id" {
  description = "Security group ID for the web tier instances"
  type        = string
}

variable "webtier_target_group_arn" {
  description = "Target group ARN the web ASG registers into"
  type        = string
}

variable "internal_alb_dns" {
  description = "DNS name of the internal ALB (passed to web user_data)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the app tier ASG"
  type        = list(string)
}

variable "app_sg_id" {
  description = "Security group ID for the app tier instances"
  type        = string
}

variable "apptier_target_group_arn" {
  description = "Target group ARN the app ASG registers into"
  type        = string
}

variable "db_endpoint" {
  description = "Database host (no port suffix)"
  type        = string
}

variable "db_port" {
  description = "Database port"
  type        = number
}

variable "db_name" {
  description = "Database name"
  type        = string
}


