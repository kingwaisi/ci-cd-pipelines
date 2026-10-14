output "public_ip" {
  description = "Die öffentliche IP-Adresse der Instanz"
  value       = aws_instance.server.public_ip
}

output "ssh_befehl" {
  description = "Fertiger Befehl zum Verbinden"
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.server.public_ip}"
}
