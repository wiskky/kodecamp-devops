output "vpc_id" {
  description = "The ID of the VPC."
  value       = aws_vpc.dream.id
}

output "subnet_id" {
  description = "The ID of the public subnet."
  value       = aws_subnet.dream.id
}

output "igw_id" {
  description = "The ID of the Internet Gateway."
  value       = aws_internet_gateway.dream.id
}

output "route_table_id" {
  description = "The ID of the route table."
  value       = aws_route_table.dream.id
}

output "security_group_id" {
  description = "The ID of the security group."
  value       = aws_security_group.web.id
}

output "ec2_id" {
  description = "The ID of the EC2 instance."
  value       = aws_instance.app.id
}

output "ec2_public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_instance.app.public_ip
}