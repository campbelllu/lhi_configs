#ami-0e83be366243f524a
#099720109477
#ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230919

data "aws_ami" "server_ami"{
    most_recent = true
    owners = ["099720109477"]

    filter{
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
    }
}