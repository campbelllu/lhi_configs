#Split between public and private subnets within one VPC.
#Private subnet will host DB
#Public subnet hosting EC2('s) to avoid NAT costs while in test-phase. All labeled for a dev-env currently, test and prod to come.
#notes to delete: vpc, subnet, route table, assoc rt+sn, igw, sg, ec2's
#Shared Resources
#VPC
resource "aws_vpc" "dev" {
  cidr_block           = "10.100.0.0/20"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "dev-vpc"
  }
}
#sg currently looks highly permissive to my junior's eye
resource "aws_security_group" "dev_sg" {
  name        = "dev_sg"
  description = "dev public subnet security group"
  vpc_id      = aws_vpc.dev.id

  # ingress {
  #   description = "All you can access, buffet."
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"] #What can get into subnet? Only for demonstration purposes! Always only allow specifics for ingress!! Also applies for below examples.
  # }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Remember to later refine as app requirements denote.
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Remember to later refine as app requirements denote.
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Remember to later refine as app requirements denote.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #Where can subnet get to?
  }
}
#Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.100.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-2a"

  tags = {
    Name = "dev-public-subnet"
  }
}
#igw
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "dev-igw"
  }
}
#pub_rt
resource "aws_route_table" "dev_public_rt" {
  vpc_id = aws_vpc.dev.id

  tags = {
    Name = "dev-rt"
  }
}
#find me on them internets
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.dev_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}
#tie rt and sn together
resource "aws_route_table_association" "dev_public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.dev_public_rt.id
}
#key pair for public ec2's
resource "aws_key_pair" "lhi_auth" {
  key_name   = "lhikey"
  public_key = file("~/.ssh/lhikey.pub")
}
#public ec2-1
resource "aws_instance" "dev_node" {
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.server_ami.id
  key_name               = aws_key_pair.lhi_auth.id
  vpc_security_group_ids = [aws_security_group.dev_sg.id]
  subnet_id              = aws_subnet.public_subnet.id
  user_data              = file("userdata.tpl")

  tags = {
    Name = "dev_node1"
  }

  # root_block_device{
  #   volume_size = 8 #already default
  # }
}

#Private Subnet
#Needs subnet, route table, assoc rt+sn, somehow ec2's and db need to talk(how do private and public subnets talk? thru the next part?), sg(the next part[spoiler: it wasn't the next part. sg's act on instance lvl. acl's act on subnet-lvl, in-n-out of vpc, my dude.]), rds('s?) for apps
#answers above q? https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group 
#also look at __ just to be safe: an acl for the private sn: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/network_acl
## more documentation to connect ec2 and rds https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_VPC.Scenarios.html -more general, used, good to del
##
#Public Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.dev.id
  cidr_block              = "10.100.2.0/24"
  # map_private_ip_on_launch = true
  map_public_ip_on_launch = false
  availability_zone       = "us-east-2a"

  tags = {
    Name = "dev-private-subnet"
  }
}

resource "aws_security_group" "dev_priv_sg"{
  name        = "dev_priv_sg"
  description = "dev private subnet security group"
  vpc_id      = aws_vpc.dev.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.100.1.0/24"] 
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.100.1.0/24"] 
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.100.1.0/24"] 
  }

  #Also need ingress and egress for appropriate DB ports.

  egress { #We can only talk to the instances in the public subnet.
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.100.1.0/24"] #Where can subnet get to? Gotta figure out if this is necessary to ever update RDS, or through NAT, or not at all.
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] #Where can subnet get to? Gotta figure out if this is necessary to ever update RDS, or through NAT, or not at all.
  }
}

#notes
# resource "aws_eip" "nat" {
#   vpc = true
# }

# resource "aws_nat_gateway" "nat-gw" {
#   allocation_id = aws_eip.nat.id
#   subnet_id     = aws_subnet.public-subnet.id
#   depends_on    = [aws_internet_gateway.internet-gw]
# }

# resource "aws_route_table" "private-rt" {
#   vpc_id = aws_vpc.main.id
#   route {
#     cidr_block     = "0.0.0.0/0"
#     nat_gateway_id = aws_nat_gateway.nat-gw.id
#   }
# }