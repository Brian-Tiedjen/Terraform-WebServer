output "alb_sg_id" {
  value = aws_security_group.alb_public_group.id
}

output "ec2_instance_sg_id" {
  value = aws_security_group.ec2_instance_sg.id
}
