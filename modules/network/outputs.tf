output "vpc_id" {
  description = "ID of the main VPC"
  value       = aws_vpc.main-vpc.id
}

output "public_subnet_ids" {
  description = "IDs of the public (web tier) subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private (app tier) subnets"
  value       = aws_subnet.private[*].id
}

output "db_subnet_group_name" {
  description = "Name of the database subnet group"
  value       = aws_db_subnet_group.main.name
}

