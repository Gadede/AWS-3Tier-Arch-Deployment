# # ---------------------------------------------------------------------------
# # DB subnet group  (spans both database subnets)
# # ---------------------------------------------------------------------------
# resource "aws_db_subnet_group" "main" {
#   name       = "${var.project_name}-db-subnet-group"
#   subnet_ids = aws_subnet.db[*].id

#   tags = {
#     Name = "${var.project_name}-db-subnet-group"
#   }
# }

# ---------------------------------------------------------------------------
# Amazon RDS (Multi-AZ)
#   multi_az = true provisions a synchronous standby in the second AZ
#   and handles automatic failover, matching the diagram.
# ---------------------------------------------------------------------------
resource "aws_db_instance" "main" {
  identifier     = "${var.project_name}-rds-instance"
  engine         = var.db_engine
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username

  # Master password is generated and stored in AWS Secrets Manager.
  manage_master_user_password = true

  multi_az               = false # Due to the free tier, we set it to false for this demo.
  
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = {
    Name = "${var.project_name}-rds-instance"
  }
}
