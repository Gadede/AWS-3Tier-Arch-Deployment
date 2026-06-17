variable "region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-2"
}

variable "project_name" {
  description = "The name of the project, used for tagging resources"
  type        = string
  default     = "aws-3-tier-app"
}

variable "app_port" {
  description = "The port on which the application listens (for target group)"
  type        = number
  default     = 80
}

variable "db_port" {
  description = "The port on which the database listens (for target group)"
  type        = number
  default     = 3306
}

variable "availability_zones" {
  description = "List of availability zones to use for subnets"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b"]
}

variable "web_instance_type" {
  description = "EC2 instance type for web and app servers"
  type        = string
  default     = "t3.micro"
}

variable "web_asg_config" {
  description = "Configuration for the web tier Auto Scaling Group"
  type = object({
    desired_capacity = number
    max_size         = number
    min_size         = number
  })
  default = {
    desired_capacity = 2
    max_size         = 3
    min_size         = 2
  }
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.3.0/24", "10.0.4.0/24"]
}

variable "db_subnet_cidrs" {
  description = "List of CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.5.0/24", "10.0.6.0/24"]
}

