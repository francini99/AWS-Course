# main.tf

#Terraform config
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }
  required_version = ">= 1.2.0"
}

#AWS config
provider "aws" {
	region = "us-east-1"
}

#VPC config
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16" #Public IP
  enable_dns_hostnames = true
  tags = {
    Name = "My VPC"
  }
}

#AWS subnet
resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "Public Subnet"
  }
}

#AWS gateway
resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "My VPC - Internet Gateway"
  }
}

#AWS route table
resource "aws_route_table" "my_vpc_public" {
    vpc_id = aws_vpc.my_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_vpc_igw.id
    }
    tags = {
        Name = "Public Subnet Route Table"
    }
}
resource "aws_route_table_association" "my_vpc_public" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.my_vpc_public.id
}

#AWS SG
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh_sg"
  description = "Allow SSH inbound connections"
  vpc_id      = aws_vpc.my_vpc.id
  # for SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # for HTTP Apache Server
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # for RDP
  ingress {
    from_port        = 3389
    to_port          = 3389
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  # for ping
  ingress {
    from_port        = -1
    to_port          = -1
    protocol         = "icmp"
    cidr_blocks      = ["10.0.0.0/16"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_ssh_sg"
  }
}

#AWS key config
resource "aws_key_pair" "testkey" {
  key_name   = "testkey"
  public_key = file("testkey.pub")
}

#Instance1 config - ubuntu2204
resource "aws_instance" "ubuntu2204" {
  ami                         = "ami-0ec10929233384c7f" #Ubuntu Server 24.04 LTS (HVM),EBS General Purpose (SSD) Volume Type.
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.testkey.key_name
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  user_data = <<-EOF
		           #! /bin/bash
                           sudo apt-get update
		           sudo apt-get install -y apache2
		           sudo systemctl start apache2
		           sudo systemctl enable apache2
		           echo "<h1>Deployed via Terraform from $(hostname -f)</h1>" | sudo tee /var/www/html/index.html
  EOF
  tags = {
    Name = "Ubuntu 22.04"
  }
}

#Instance2 config - win2025
resource "aws_instance" "win2025" {
	ami                         = "ami-01a15dfc48279bf55" # Microsoft Windows 2025 Datacenter edition
	instance_type               = "t3.micro"
        key_name                    = aws_key_pair.testkey.key_name
        vpc_security_group_ids      = [aws_security_group.allow_ssh.id]
        subnet_id                   = aws_subnet.public.id  
	associate_public_ip_address = true
        tags = {
		Name = "Win 2025 Server"
	}
}

#Public IPs
output "instance_ubuntu2204_public_ip" {
  value = "${aws_instance.ubuntu2204.public_ip}"
}

output "instance_win2025_public_ip" {
  value = "${aws_instance.win2025.public_ip}"
}