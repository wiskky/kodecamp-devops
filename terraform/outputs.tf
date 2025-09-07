output "instance_id" {
  value = aws_instance.dream.id
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/dream-key.pem ubuntu@${aws_instance.dream.public_ip}"
}

output "public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.dream.public_ip
}
