locals {
  app_name           = "ava-rds"
  application_domain = "app.ava.duleendra.com"

  #VPC
  azs              = ["us-east-1a", "us-east-1b"]
  cidr             = "20.0.0.0/16"
  private_subnets  = ["20.0.0.0/19", "20.0.32.0/19"]
  public_subnets   = ["20.0.64.0/19", "20.0.96.0/19"]
  database_subnets = ["20.0.128.0/19", "20.0.160.0/19"]
}

################################################################################
# Setup a VPC
################################################################################
module "vpc" {
  source = "./modules/vpc"

  name               = local.app_name
  azs                = local.azs
  cidr               = local.cidr
  private_subnets    = local.private_subnets
  public_subnets     = local.public_subnets
  database_subnets   = local.database_subnets
  enable_nat_gateway = true
  single_nat_gateway = true
}

################################################################################
# Setup RDS
################################################################################
module "db" {
  source = "./modules/rds"

  identifier     = "${local.app_name}-db"
  instance_class = "db.t3.micro"

  manage_master_user_password = true
  username                    = "admin"

  db_subnet_group_name   = module.vpc.database_subnet_group
  vpc_security_group_ids = [module.rds_security_group.security_group_id]
}

################################################################################
# Setup RDS security group
################################################################################
module "rds_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = ">= 5.0"

  name        = "${local.app_name}db-sg"
  description = "RDS security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_source_security_group_id = [
    {
      rule                     = "mysql-tcp"
      source_security_group_id = module.verified_access_sg.security_group_id
    },
  ]
}

################################################################################
# Setup AWS Verified Access resources
################################################################################


################################################################################
# Setup  Verified Access trust provider
################################################################################
resource "aws_verifiedaccess_trust_provider" "trust_provider" {
  description              = "IAM trust provider"
  policy_reference_name    = "iam" #Refer to this name in the policy document
  trust_provider_type      = "user"
  user_trust_provider_type = "iam-identity-center"
  tags = {
    Name = "Iam Identity Center"
  }
}

################################################################################
# Setup central Verified Access instance
################################################################################
resource "aws_verifiedaccess_instance" "this" {
  description = "Central AVA instance"
  tags = {
    Name = "AVA Instance"
  }
}

################################################################################
# Attach trust provider to Verified Access instance
################################################################################
resource "aws_verifiedaccess_instance_trust_provider_attachment" "this" {
  verifiedaccess_instance_id       = aws_verifiedaccess_instance.this.id
  verifiedaccess_trust_provider_id = aws_verifiedaccess_trust_provider.trust_provider.id
}

################################################################################
# Setup Verified Access group
################################################################################
resource "aws_verifiedaccess_group" "this" {
  verifiedaccess_instance_id = aws_verifiedaccess_instance.this.id
  policy_document            = <<-EOT
      permit(principal, action, resource)
      when {
        context.iam.user.email.address like "*@gmail.com"
      };
      EOT
  tags = {
    Name = "AVA Group"
  }

  depends_on = [
    aws_verifiedaccess_instance_trust_provider_attachment.this
  ]
}

################################################################################
# Security group for Verified Access endpoint
################################################################################
module "verified_access_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"

  name   = "${local.app_name}-verified-access-sg"
  vpc_id = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]

  ingress_rules = [
    "mysql-tcp"
  ]
  egress_cidr_blocks = ["0.0.0.0/0"]
   egress_rules = [
   "all-all"
   ]
}