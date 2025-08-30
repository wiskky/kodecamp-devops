variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name (for SSH)"
  type        = string
  default     = "dream-key"
}

# ---------- Ubuntu AMI ----------
variable "ubuntu_ami" {
  description = "Ubuntu ami"
  default = "ami-0a716d3f3b16d290c"
}