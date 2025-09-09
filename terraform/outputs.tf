output "instance_id" {
  value = aws_instance.dream.id
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/mynew-key ubuntu@${aws_instance.dream.public_ip}"
}

output "public_ip" {
  description = "Public IP of EC2 instance"
  value       = aws_instance.dream.public_ip
}

output "key_pair_name" {
  description = "Name of the generated key pair"
  value       = aws_key_pair.dream_generated_key.key_name
}
