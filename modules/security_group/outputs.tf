output "public_alb_sg_id" {
  description = "Security group ID for the internet-facing ALB"
  value       = aws_security_group.public_alb.id
}

output "webtier_sg_id" {
  description = "Security group ID for the web tier"
  value       = aws_security_group.webtier-sg.id
}

output "internal_alb_sg_id" {
  description = "Security group ID for the internal ALB"
  value       = aws_security_group.internal_alb.id
}

output "app_sg_id" {
  description = "Security group ID for the app tier"
  value       = aws_security_group.app.id
}

output "db_sg_id" {
  description = "Security group ID for the database tier"
  value       = aws_security_group.db.id
}