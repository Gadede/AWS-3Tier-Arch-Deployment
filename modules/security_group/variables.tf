variable "project_name" {
  description = "The name of the project, used for tagging resources"
  type        = string
  default     = "aws-3tier"
}

variable "app_port" {
  description = "The port on which the application listens (for target group)"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "The port on which the database listens (for target group)"
  type        = number
  default     = 5432
}

variable "vpc_id" {
  description = "The VPC ID in which to create the security groups"
  type        = string
}


