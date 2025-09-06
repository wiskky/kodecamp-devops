variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

# variable "az" {
#   description = "Availability Zone for the subnet"
#   type        = string
#   default     = "us-east-1a"
# }

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "dream-key"
}

variable "ssh_public_key" {
  description = "Public key for SSH access (ssh-rsa ... or ssh-ed25519 ...)"
  type        = string
}
