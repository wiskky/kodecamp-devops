output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.web.public_ip
}

output "security_group_id" {
  value       = aws_security_group.web_sg.id
  description = "Web security group ID"
}

output "subnet_id" {
  value       = aws_subnet.public.id
}

output "vpc_id" {
  value       = aws_vpc.main.id
}
