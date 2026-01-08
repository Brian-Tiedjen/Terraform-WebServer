output "vpc_id" {
  value = module.vpc.vpc_id
}

output "VPC_ID" {
  value = module.vpc.vpc_id
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "availability_zones" {
  value = data.aws_availability_zones.available.names
}

output "alb_dns_name" {
  value = module.alb.alb_dns_name
}

output "alb_logs_bucket_name" {
  value = module.logging.alb_logs_bucket_name
}

output "target_group_arn" {
  value = module.alb.target_group_arn
}

output "alb_url" {
  value = module.alb.alb_url
}

output "asg_name" {
  value = module.compute.asg_name
}

output "instance_role_name" {
  value = module.iam.instance_role_name
}

output "lock_table_name" {
  value = module.database.lock_table_name
}

output "waf_web_acl_arn" {
  value = module.waf.web_acl_arn
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}
