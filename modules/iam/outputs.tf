output "instance_profile_name" {
  value = aws_iam_instance_profile.ec2_profile.name
}

output "instance_role_name" {
  value = aws_iam_role.ec2_cw_role.name
}
