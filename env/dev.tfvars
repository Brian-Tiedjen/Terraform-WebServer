
environment      = "dev"
vpc_cidr         = "10.10.1.0/24"
desired_capacity = 2
instance_type    = "t3.micro"


public_subnets = {
  public_a = {
    cidr = "10.10.1.0/26"
    az   = "us-east-2a"
  }
  public_b = {
    cidr = "10.10.1.64/26"
    az   = "us-east-2b"
  }
}

private_subnets = {
  private_a = {
    cidr = "10.10.1.128/26"
    az   = "us-east-2a"
  }
  private_b = {
    cidr = "10.10.1.192/26"
    az   = "us-east-2b"
  }
}
