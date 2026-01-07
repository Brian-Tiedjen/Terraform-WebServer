variable "environment" {
  type = string
}
variable "instance_type" {
  default = "t3.micro"
}
variable "desired_capacity" {
  default = 1
}
variable "max_size" {
  default = 3
}
variable "min_size" {
  default = 1
}
variable "security_group_id" {
  type = string
}
variable "instance_profile_name" {
  type = string
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "target_group_arns" {
  type = list(string)
}
