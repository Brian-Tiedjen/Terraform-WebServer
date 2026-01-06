
variable "region" {
  default = "us-east-2"
}

variable "vpc_name" {
  type = string

}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = map(object({
    cidr = number
    az   = string
  }))

  default = {
    public_subnet_1 = { cidr = 1, az = "us-east-2a" }
    public_subnet_2 = { cidr = 2, az = "us-east-2b" }
  }
}

variable "private_subnets" {
  type = map(object({
    cidr = number
    az   = string
  }))
  default = {
    private_subnet_1 = { cidr = 10, az = "us-east-2a" }
    private_subnet_2 = { cidr = 11, az = "us-east-2b" }
  }
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
