variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-north-1"
}

variable "ssh_key_name" {
  description = "Existing EC2 key pair name (for SSH)"
  type        = string
}