output "vpc_id"           { value = aws_vpc.dream.id }
output "subnet_id"        { value = aws_subnet.dream.id }
output "igw_id"           { value = aws_internet_gateway.dream.id }
output "route_table_id"   { value = aws_route_table.dream.id }
output "security_group_id"{ value = aws_security_group.web.id }
output "ec2_id"           { value = aws_instance.app.id }
output "ec2_public_ip"    { value = aws_instance.app.public_ip }