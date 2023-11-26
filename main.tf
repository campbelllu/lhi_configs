#need vpc, LB, ec2's, eks, rds?
#vpc
resource "aws_vpc" "dev" {
  cidr_block = "10.100.0.0/20"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "dev"
  }
}