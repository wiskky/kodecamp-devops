terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    template = {
      source  = "hashicorp/template"
      version = ">= 2.2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

############################
# Part 1 – Networking
############################
resource "aws_vpc" "dream" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dream-vpc"
  }
}

resource "aws_subnet" "dream" {
  vpc_id                  = aws_vpc.dream.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  #availability_zone       = var.az

  tags = {
    Name = "dream-subnet"
  }
}

resource "aws_internet_gateway" "dream" {
  vpc_id = aws_vpc.dream.id
  tags = {
    Name = "dream-igw"
  }
}

resource "aws_route_table" "dream" {
  vpc_id = aws_vpc.dream.id
  tags = {
    Name = "dream-rt"
  }
}

resource "aws_route" "default_to_igw" {
  route_table_id         = aws_route_table.dream.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dream.id
}

resource "aws_route_table_association" "dream_subnet_assoc" {
  subnet_id      = aws_subnet.dream.id
  route_table_id = aws_route_table.dream.id
}

############################
# Security Group
############################
resource "aws_security_group" "dream_ec2_sg" {
  name        = "dream-ec2-sg"
  description = "Allow SSH, HTTP and app port"
  vpc_id      = aws_vpc.dream.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend app on port 3000"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "dream-ec2-sg" }
}

############################
# IAM Role for EC2 (CloudWatch + SSM optional)
############################
resource "aws_iam_role" "ec2_role" {
  name = "dream-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = { Service = "ec2.amazonaws.com" }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "dream-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

############################
# Part 2 – EC2 Instance
############################
data "aws_ami" "ubuntu_lts" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# resource "aws_key_pair" "dream_key" {
#   key_name   = var.key_name
#   public_key = var.ssh_public_key
# }

# Render user data from template
locals {
  cw_agent_config = file("${path.module}/cloudwatch-agent.json")
  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    cw_config_json = replace(local.cw_agent_config, "\n", " ")
  })
}

resource "aws_instance" "dream" {
  ami                         = data.aws_ami.ubuntu_lts.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.dream.id
  vpc_security_group_ids      = [aws_security_group.dream_ec2_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  user_data                   = local.user_data

  tags = {
    Name = "dream-ec2"
  }
}

############################
# Part 3 – CloudWatch Alarm
############################
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "dream-ec2-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Average"
  threshold           = 70
  alarm_description   = "Alarm when CPU > 70% for 2 consecutive minutes"
  dimensions = {
    InstanceId = aws_instance.dream.id
  }
}
