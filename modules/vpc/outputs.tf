output "vpc_id" {
  value = aws_vpc.vpc.id
}
output "public_subnet_ids" {
  value = [for subnet in values(aws_subnet.public_subnets) : subnet.id]
}

output "private_subnet_ids" {
  value = [for subnet in values(aws_subnet.private_subnets) : subnet.id]
}
