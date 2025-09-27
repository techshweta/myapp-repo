terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
        }
    }
}
provider "aws" {
  region = var.region
}

# --- VPC ---
resource "aws_vpc" "this" {
  for_each = toset(var.envs)
  cidr_block = each.key == "dev" ? "10.0.0.0/16" : each.key == "uat" ? "10.1.0.0/16" : "10.2.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "${each.key}-vpc"
    Env  = each.key
  }
}


# --- Subnet ---
resource "aws_subnet" "this" {
  for_each = aws_vpc.this
  vpc_id            = each.value.id
  cidr_block        = each.key == "dev" ? "10.0.1.0/24" : each.key == "uat" ? "10.1.1.0/24" : "10.2.1.0/24"
  availability_zone = "${var.region}a"
  tags = {
    Name = "${each.key}-subnet"
    Env  = each.key
  }
}

# --- Internet Gateway ---
resource "aws_internet_gateway" "this" {
  for_each = aws_vpc.this
  vpc_id = each.value.id
  tags = {
    Name = "${each.key}-igw"
    Env  = each.key
  }
}

# --- Route Table ---
resource "aws_route_table" "this" {
  for_each = aws_vpc.this
  vpc_id = each.value.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[each.key].id
  }
  tags = {
    Name = "${each.key}-rt"
    Env  = each.key
  }
}

resource "aws_route_table_association" "a" {
  for_each = aws_subnet.this
  subnet_id      = each.value.id
  route_table_id = aws_route_table.this[each.key].id
}

# --- Security Group ---
resource "aws_security_group" "allow_web" {
  for_each = aws_vpc.this
  vpc_id      = each.value.id
  name        = "${each.key}-sg"
  description = "allow ssh + http + tomcat"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8081
    to_port     = 8081
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${each.key}-sg"
    Env  = each.key
  }
}

data "aws_ami" "ubuntu" {
     most_recent = true 
     owners = ["099720109477"] # Canonical 
     filter {
         name = "name" 
         values = ["ubuntu/images/hvm-ssd/ubuntu-*-amd64-server-*"] 
         } 
    }

# --- EC2 Instance ---
resource "aws_instance" "app" {
  for_each = aws_subnet.this
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = each.value.id
  vpc_security_group_ids = [aws_security_group.allow_web[each.key].id]
  key_name               = var.ssh_key_name
  associate_public_ip_address = true 

  tags = {
    Name = "${each.key}-tomcat"
    Env  = each.key
  }

  user_data = <<-EOF
              #!/bin/bash
              set -e
              sudo apt update -y
              sudo apt install -y openjdk-11-jdk tomcat9 tomcat9-admin
              sudo systemctl enable tomcat9
              sudo systemctl start tomcat9
              sudo apt-get install -y ca-certificates curl gnupg lsb-release
              sudo mkdir -p /etc/apt/keyrings
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
              echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
              sudo apt-get update -y
              sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
              sudo usermod -aG docker ubuntu
              sudo systemctl enable docker
              sudo systemctl start docker
              EOF
}

# --- Output ---
output "ec2_public_ip" {
  value = { for k, v in aws_instance.app : k => v.public_ip }
}
