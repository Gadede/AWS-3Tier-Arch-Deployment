# output "vpc_id" {
#   description = "ID of the main VPC"
#   value       = aws_vpc.main-vpc.id
# }

# output "webtier_sg_id" {
#   description = "ID of the web tier security group"
#   value       = aws_security_group.webtier-sg.id
# }

# output "internal_alb_sg_id" {
#   description = "ID of the internal ALB security group"
#   value       = aws_security_group.internal_alb.id
# }

# output "app_sg_id" {
#   description = "ID of the app tier security group"
#   value       = aws_security_group.app.id
# }

# output "db_sg_id" {
#   description = "ID of the database security group"
#   value       = aws_security_group.db.id
# }

# output "db_subnet_group_name" {
#   description = "Name of the database subnet group"
#   value       = aws_db_subnet_group.main.name
# }

output "vpc_id" {
  value = module.network.vpc_id
}
output "db_subnet_group_name" {
  value = module.network.db_subnet_group_name
}

output "internal_alb_dns" {
  value = module.alb.internal_alb_dns
}