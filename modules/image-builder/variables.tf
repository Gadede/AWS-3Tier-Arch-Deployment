variable "project_name" {
  description = "Project name used for tagging and resource naming"
  type        = string
  default     = "aws-3tier"
}

variable "region" {
  description = "AWS region for the build and AMI distribution"
  type        = string
  default     = "us-east-2"
}

variable "base_ami_id" {
  description = "Base AMI to build from (e.g. the latest Ubuntu AMI from your data source)"
  type        = string
}

variable "build_subnet_id" {
  description = "Subnet ID where the temporary build instance runs (a private subnet is fine; it needs outbound via NAT for apt)"
  type        = string
}

variable "build_security_group_id" {
  description = "Security group for the build instance (needs outbound 443/80 for package downloads; no inbound required)"
  type        = string
}

variable "component_version" {
  description = "Semantic version for the Image Builder component. Bump when you change the build steps."
  type        = string
  default     = "1.0.0"
}

variable "recipe_version" {
  description = "Semantic version for the image recipe. Bump when component or base image changes."
  type        = string
  default     = "1.0.0"
}

variable "build_schedule" {
  description = "Cron expression for scheduled builds (UTC). Default: 03:00 on the 1st of each month."
  type        = string
  default     = "cron(0 3 1 * ?)"
}
