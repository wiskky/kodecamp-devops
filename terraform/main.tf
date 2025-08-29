# Part 1: Networking Setup
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Creating VPC, Subnet and IGW 
resource "aws_vpc" "dream" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "dream-vpc" }
}

resource "aws_subnet" "dream" {
  vpc_id                  = aws_vpc.dream.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "dream-subnet" }
}

resource "aws_internet_gateway" "dream" {
  vpc_id = aws_vpc.dream.id
  tags   = { Name = "dream-igw" }
}

resource "aws_route_table" "dream" {
  vpc_id = aws_vpc.dream.id
  tags   = { Name = "dream-rt" }
}

resource "aws_route" "default_inet" {
  route_table_id         = aws_route_table.dream.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.dream.id
}

resource "aws_route_table_association" "subnet_assoc" {
  subnet_id      = aws_subnet.dream.id
  route_table_id = aws_route_table.dream.id
}

# ---------- Security Group ----------
resource "aws_security_group" "web" {
  name        = "dream-sg"
  description = "Allow SSH and HTTP"
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
    description = "Custom application port"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = { 
    Name = "dream-sg" 
  }
}

# ---------- IAM for CloudWatch Agent ----------
data "aws_iam_policy" "cw_agent" {
  arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy" "ssm_core" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role" "cw_role" {
  name = "dream-cw-agent-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_cw_agent" {
  role       = aws_iam_role.cw_role.name
  policy_arn = data.aws_iam_policy.cw_agent.arn
}

resource "aws_iam_role_policy_attachment" "attach_ssm" {
  role       = aws_iam_role.cw_role.name
  policy_arn = data.aws_iam_policy.ssm_core.arn
}

resource "aws_iam_instance_profile" "cw_profile" {
  name = "dream-cw-instance-profile"
  role = aws_iam_role.cw_role.name
}

# ---------- AMI (Latest Ubuntu LTS 22.04 Jammy) ----------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ---------- EC2 ----------
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.dream.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.cw_profile.name
  key_name                    = var.ssh_key_name 

  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg lsb-release docker.io docker-compose-plugin
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu || true
    CW_DEB="/tmp/amazon-cloudwatch-agent.deb"
    curl -fsSL -o ${CW_DEB} https://amazoncloudwatch-agent.s3.amazonaws.com/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
    dpkg -i ${CW_DEB}
    mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
    cat >/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<JSON
    {
      "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "root"
      },
      "metrics": {
        "namespace": "EC2/DreamVacation",
        "append_dimensions": {
          "InstanceId": "${aws_instance.app.id}" # Corrected "self" reference
        },
        "metrics_collected": {
          "cpu": {
            "measurement": ["cpu_usage_idle", "cpu_usage_system", "cpu_usage_user"],
            "metrics_collection_interval": 60
          }
        }
      }
    }
    JSON
    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
  EOF
  tags = { Name = "dream-ec2" }
}

# ---------- CloudWatch Alarm (CPU > 70% for 2 x 1-min) ----------
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "dream-ec2-high-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  threshold           = 30
  period              = 60
  statistic           = "Average"
  dimensions = {
    InstanceId = aws_instance.app.id
  }
  metric_name = "cpu_usage_idle"
  namespace   = "EC2/DreamVacation"
  alarm_description  = "CPU > 70% for 2 minutes on dream-ec2"
}