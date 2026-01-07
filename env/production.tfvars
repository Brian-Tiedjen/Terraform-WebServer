environment   = "production"
vpc_cidr      = "10.10.0.0/16"
instance_type = "t3.micro"
public_subnets = {
  public_a = {
    cidr = 10
    az   = "us-east-2a"
  }
  public_b = {
    cidr = 20
    az   = "us-east-2b"
  }
}

private_subnets = {
  private_a = {
    cidr = 100
    az   = "us-east-2a"
  }
  private_b = {
    cidr = 110
    az   = "us-east-2b"
  }
}

desired_capacity = 1