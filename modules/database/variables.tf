variable "project_name" {
  description = "The name of the project, used for tagging resources"
  type        = string
  default     = "aws-3-tier-app"
}

variable "db_engine" {
  description = "The database engine to use for the RDS instance"
  type        = string
  default     = "mysql"
}

variable "db_engine_version" {
  description = "The version of the database engine"
  type        = string
  default     = "8.4.8"
}

variable "db_instance_class" {
  description = "The instance class for the RDS instance"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "The allocated storage for the RDS instance (in GB)"
  type        = number
  default     = 20  
  
}

variable "db_max_allocated_storage" {
  description = "The maximum allocated storage for the RDS instance (in GB)"
  type        = number
  default     = 100
  
}

variable "db_name" {
  description = "The name of the database to create on the RDS instance"
  type        = string
  default     = "mydatabase"
}

variable "db_username" {
  description = "The master username for the RDS instance"
  type        = string
  default     = "admin"
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group (from the network module)"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "Security group IDs to attach to the RDS instance"
  type        = list(string)
}