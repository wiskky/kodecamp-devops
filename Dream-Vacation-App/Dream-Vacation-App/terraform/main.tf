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
  region = var.aws_region
}

# ---------------- Networking ----------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "dream-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  tags = { Name = "dream-public-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "dream-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "dream-public-rt" }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------- Security Group ----------------
resource "aws_security_group" "web_sg" {
  name        = "dream-web-sg"
  description = "Allow SSH and app port 3000"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Dream App"
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

# ---------------- IAM for CloudWatch Agent ----------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-cloudwatch-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "cw_attach" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-cloudwatch-profile"
  role = aws_iam_role.ec2_role.name
}

# ---------------- EC2 Instance ----------------
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  key_name               = var.ssh_key_name

  # IMPORTANT: bash user_data only (no cloud-init per your request)
  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              export DEBIAN_FRONTEND=noninteractive
              apt-get update -y
              apt-get install -y docker.io docker-compose-plugin amazon-cloudwatch-agent
              systemctl enable docker
              systemctl start docker

              # CloudWatch Agent config (system + docker logs, basic metrics)
              mkdir -p /opt/aws/amazon-cloudwatch-agent/etc
              cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json <<'JSON'
              {
                "agent": {
                  "metrics_collection_interval": 60,
                  "logfile": "/opt/aws/amazon-cloudwatch-agent/logs/agent.log"
                },
                "metrics": {
                  "append_dimensions": {
                    "InstanceId": "$${aws:InstanceId}"
                  },
                  "metrics_collected": {
                    "mem": {
                      "measurement": ["mem_used_percent"],
                      "metrics_collection_interval": 60
                    },
                    "disk": {
                      "measurement": ["used_percent"],
                      "metrics_collection_interval": 60,
                      "resources": ["*"]
                    }
                  }
                },
                "logs": {
                  "logs_collected": {
                    "files": {
                      "collect_list": [
                        { "file_path": "/var/log/syslog", "log_group_name": "ec2-syslog", "log_stream_name": "{instance_id}" },
                        { "file_path": "/var/log/cloud-init.log", "log_group_name": "ec2-cloudinit", "log_stream_name": "{instance_id}" },
                        { "file_path": "/var/lib/docker/containers/*/*.log", "log_group_name": "docker-containers", "log_stream_name": "{instance_id}" }
                      ]
                    }
                  }
                }
              }
              JSON

              systemctl enable amazon-cloudwatch-agent
              systemctl restart amazon-cloudwatch-agent || systemctl start amazon-cloudwatch-agent
              EOF

  tags = { Name = "dream-ec2" }
}

# ---------------- CloudWatch Dashboard ----------------
resource "aws_cloudwatch_dashboard" "ec2_dashboard" {
  dashboard_name = "EC2-Monitoring-Dashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        "type": "metric",
        "x": 0, "y": 0, "width": 12, "height": 6,
        "properties": {
          "view": "timeSeries",
          "stacked": false,
          "region": var.aws_region,
          "title": "EC2 CPU Utilization",
          "metrics": [
            ["AWS/EC2","CPUUtilization","InstanceId", aws_instance.web.id]
          ]
        }
      },
      {
        "type": "metric",
        "x": 0, "y": 6, "width": 12, "height": 6,
        "properties": {
          "view": "timeSeries",
          "stacked": false,
          "region": var.aws_region,
          "title": "Memory Used (%)",
          "metrics": [
            ["CWAgent","mem_used_percent","InstanceId", aws_instance.web.id]
          ]
        }
      },
      {
        "type": "metric",
        "x": 0, "y": 12, "width": 12, "height": 6,
        "properties": {
          "view": "timeSeries",
          "stacked": false,
          "region": var.aws_region,
          "title": "Disk Used (%)",
          "metrics": [
            ["CWAgent","disk_used_percent","InstanceId", aws_instance.web.id]
          ]
        }
      }
    ]
  })
}
