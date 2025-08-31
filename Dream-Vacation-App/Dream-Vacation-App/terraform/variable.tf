variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-0a716d3f3b16d290c" 
}


variable "ec2_key_pair" {
  description = "Name of an existing EC2 Key Pair for SSH"
  type        = string
  default     = dream-key
}

