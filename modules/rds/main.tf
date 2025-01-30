module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~>6.9.0"

  identifier = var.identifier

  engine               = var.engine
  engine_version       = var.engine_version
  family               = var.family
  major_engine_version = var.major_engine_version
  instance_class       = var.instance_class

  username                             = var.username
  manage_master_user_password          = var.manage_master_user_password
  manage_master_user_password_rotation = var.manage_master_user_password_rotation

  iam_database_authentication_enabled = var.iam_database_authentication_enabled

  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = var.vpc_security_group_ids

  allocated_storage = var.allocated_storage

  deletion_protection = false
  skip_final_snapshot = true
  storage_encrypted   = false
  multi_az            = false
}