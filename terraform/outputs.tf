output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "subnet_id" {
  value       = aws_subnet.public_a.id
  description = "Public subnet ID"
}

output "route_table_id" {
  value       = aws_route_table.public.id
  description = "Route table ID"
}

output "ec2_public_ip" {
  value       = aws_instance.app.public_ip
  description = "EC2 public IP"
}


