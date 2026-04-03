terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.81.0"
    }
  }
  required_version = ">= 1.10.2"
}

provider "aws" {
	region = "eu-central-1"
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "My VPC"
  }
}

resource "aws_subnet" "public" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_internet_gateway" "my_vpc_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "My VPC - Internet Gateway"
  }
}

resource "aws_route_table" "my_vpc_eu_central_1c_public" {
    vpc_id = aws_vpc.my_vpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.my_vpc_igw.id
    }
    tags = {
        Name = "Public Subnet Route Table"
    }
}
resource "aws_route_table_association" "my_vpc_eu_central_1c_public" {
    subnet_id      = aws_subnet.public.id
    route_table_id = aws_route_table.my_vpc_eu_central_1c_public.id
}

resource "aws_security_group" "sg_config" {
  name        = "allow_ssh_sg"
  description = "Allow SSH inbound connections"
  vpc_id      = aws_vpc.my_vpc.id
  # for SSH
  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  # for HTTP Apache Server
  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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
  # EFS mount target, important to connect with NFS file system, it must be added.
  ingress {
    from_port        = 2049
    to_port          = 2049
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
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

#Instance1 config - ubuntu2204
resource "aws_instance" "ubuntu2204" {
  ami                         = "ami-0ec10929233384c7f" #Ubuntu Server 24.04 LTS (HVM),EBS General Purpose (SSD) Volume Type.
  instance_type               = "t3.small"
  key_name                    = aws_key_pair.testkey.key_name
  vpc_security_group_ids      = [aws_security_group.sg_config.id]
  subnet_id                   = aws_subnet.public.id
  associate_public_ip_address = true
  tags = {
    Name = "Ubuntu 22.04"
  }
}

#Instance2 config - win2025
resource "aws_instance" "win2025" {
	ami                         = "ami-01a15dfc48279bf55" # Microsoft Windows 2025 Datacenter edition
	instance_type               = "t3.micro"
        key_name                    = aws_key_pair.testkey.key_name
        vpc_security_group_ids      = [aws_security_group.sg_config.id]
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