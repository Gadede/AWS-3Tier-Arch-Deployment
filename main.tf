module "network" {
  source               = "./modules/network"
  project_name         = var.project_name
  vpc_cidr             = var.vpc_cidr
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  db_subnet_cidrs      = var.db_subnet_cidrs
}

module "security_group" {
  source       = "./modules/security_group"
  project_name = var.project_name
  vpc_id       = module.network.vpc_id
  app_port     = var.app_port
  db_port      = var.db_port
}

module "alb" {
  source             = "./modules/alb"
  project_name       = var.project_name
  app_port           = var.app_port
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  private_subnet_ids = module.network.private_subnet_ids
  public_alb_sg_id   = module.security_group.public_alb_sg_id
  internal_alb_sg_id = module.security_group.internal_alb_sg_id
}

module "database" {
  source                   = "./modules/database"
  project_name             = var.project_name
  db_engine                = "mysql"
  db_engine_version        = "8.4.8"
  db_instance_class        = "db.t3.micro"
  db_allocated_storage     = 20
  db_max_allocated_storage = 100
  db_name                  = "myappdb"
  db_username              = "admin"
  db_subnet_group_name     = module.network.db_subnet_group_name
  vpc_security_group_ids   = [module.security_group.db_sg_id]
}

module "compute" {
  source            = "./modules/compute"
  project_name      = var.project_name
  web_instance_type = var.web_instance_type
  app_port          = var.app_port
  web_asg_config    = var.web_asg_config
  ami_id            = data.aws_ami.ubuntu.id

  # web tier
  public_subnet_ids        = module.network.public_subnet_ids
  web_sg_id                = module.security_group.webtier_sg_id
  webtier_target_group_arn = module.alb.webtier_target_group_arn
  internal_alb_dns         = module.alb.internal_alb_dns

  # app tier
  private_subnet_ids       = module.network.private_subnet_ids
  app_sg_id                = module.security_group.app_sg_id
  apptier_target_group_arn = module.alb.apptier_target_group_arn
  db_endpoint              = module.database.db_address # host only
  db_port                  = var.db_port
  db_name                  = "myappdb"
}

#----------------------------------------------------
# Create S3 Bucket to be used as the remote backend
#----------------------------------------------------

# # Create S3 bucket 
# resource "aws_s3_bucket" "terraform_state" {
#   bucket = "richkode-tf-state-bucket"

#   # lifecycle {
#   #   prevent_destroy = true
#   # }
# }

# # Enable Versioning
# resource "aws_s3_bucket_versioning" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   versioning_configuration {
#     status = "Enabled"
#   }
# }

# # Enable server side encryption
# resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
#   bucket = aws_s3_bucket.terraform_state.id
#   rule {
#     apply_server_side_encryption_by_default {
#       sse_algorithm = "AES256"
#     }
#   }
# }

# # Block public access to the bucket
# resource "aws_s3_bucket_public_access_block" "terraform_state" {
#   bucket                  = aws_s3_bucket.terraform_state.id
#   block_public_acls       = true
#   block_public_policy     = true
#   ignore_public_acls      = true
#   restrict_public_buckets = true
# }

module "image_builder" {
  source                  = "./modules/image-builder"
  project_name            = var.project_name
  region                  = var.region
  base_ami_id             = data.aws_ami.ubuntu.id
  build_subnet_id         = module.network.private_subnet_ids[0]
  build_security_group_id = module.security_group.app_sg_id
}