terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "proj-vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.proj-vpc.id

  tags = {
    Name = "gateway1"
  }
}

resource "aws_route_table" "proj-rt" {
  vpc_id = aws_vpc.proj-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = aws_egress_only_internet_gateway.gw.id
  }

  tags = {
    Name = "rt1"
  }
}

resource "aws_subnet" "proj-subnet" {
  vpc_id     = aws_vpc.proj-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "subnet1"
  }
}

resource "aws_route_table_association" "proj-sub-rt-asso" {
  subnet_id      = aws_subnet.proj-subnet.id
  route_table_id = aws_route_table.proj-rt.id
}

resource "aws_security_group" "proj-sg" {
  name        = "proj-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.proj-vpc.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 65000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "proj-sg1"
  }
}

resource "aws_network_interface" "proj-ni" {
  subnet_id       = aws_subnet.proj-subnet.id
  private_ips     = ["10.0.1.10"]  # Choose a valid IP within the subnet range
  security_groups = [aws_security_group.proj-sg.id]
}

resource "aws_egress_only_internet_gateway" "gw" {
  vpc_id = aws_vpc.proj-vpc.id
}

resource "aws_eip" "proj-eip" {
  domain                  = "vpc"
  network_interface       = aws_network_interface.proj-ni.id
  associate_with_private_ip = "10.0.1.10"  # Make sure it matches the private IP of the network interface
}

resource "aws_instance" "prod-server" {
  ami           = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  key_name      = "assignment"

  network_interface {
    device_index          = 0
    network_interface_id  = aws_network_interface.proj-ni.id
  }

  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install docker.io -y
    sudo service docker enable
    sudo service docker start
    sudo docker run -itd -p 8084:8081 moreaniket/insurance:1.0
  EOF

  tags = {
    name = "prod-server"
  }
}
