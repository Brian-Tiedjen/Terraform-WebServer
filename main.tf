module "vpc" {
  source          = "./modules/vpc"
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  environment     = var.environment
}

# Availability zones for outputs (matches pre-module outputs)
data "aws_availability_zones" "available" {
  state = "available"
}

#call logging module
module "logging" {
  source      = "./modules/logging"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
}

module "iam" {
  source = "./modules/iam"
}

module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id
}

#call alb module
module "alb" {
  source            = "./modules/alb"
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  logs_bucket_name  = module.logging.logs_bucket_name
  environment       = var.environment
}

module "compute" {
  source = "./modules/compute"

  environment           = var.environment
  instance_type         = var.instance_type
  desired_capacity      = var.desired_capacity
  security_group_id     = module.security.ec2_instance_sg_id
  instance_profile_name = module.iam.instance_profile_name
  private_subnet_ids    = module.vpc.private_subnet_ids
  target_group_arns     = module.alb.demo_alb_group_arns
}
