variable "project_name" {
  type    = string
  default = "aws-3tier"
}

variable "app_port" {
  type    = number
  default = 80
}

variable "vpc_id" {
  description = "VPC ID for the target groups"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the internet-facing ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnets for the internal ALB"
  type        = list(string)
}

variable "public_alb_sg_id" {
  description = "Security group ID for the public ALB"
  type        = string
}

variable "internal_alb_sg_id" {
  description = "Security group ID for the internal ALB"
  type        = string
}