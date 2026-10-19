output "public_ip" {
  description = "Die öffentliche IP-Adresse der Instanz"
  value       = aws_instance.server.public_ip
}

output "ssh_befehl" {
  description = "Fertiger Befehl zum Verbinden"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.server.public_ip}"
}


output "ami_id" {
  description = "Die AMI-ID der Instanz"
  value       = aws_instance.server.ami
}

output "arn_id" {
  description = "Die ARN-ID der Instanz"
  value       = aws_instance.server.arn
}

output "instance_id" {
  description = "Die Instanz-ID der Instanz"
  value       = aws_instance.server.id
}