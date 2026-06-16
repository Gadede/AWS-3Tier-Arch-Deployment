output "db_endpoint" {
  description = "Endpoint of the database"
  value       = aws_db_instance.main.endpoint
}

output "db_username" {
  description = "Username for the database"
  value       = aws_db_instance.main.username
}

output "db_address" {
  description = "Database host only, no port"
  value       = aws_db_instance.main.address
}
