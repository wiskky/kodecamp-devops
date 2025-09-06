output "instance_id" {
  value = aws_instance.dream.id
}

output "public_ip" {
  value = aws_instance.dream.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/dream-key.pem ubuntu@${aws_instance.dream.public_ip}"
}
