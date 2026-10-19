# ---------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------

resource "aws_security_group" "server" {
  name        = "terraform-kurs-sg"
  description = "Firewall fuer den Terraform-Kurs-Server"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.vorname}-sg"
  }
}

# Eingehend: SSH (Port 22) von überall
resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.server.id
  description       = "SSH"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

# Ausgehend: alles erlaubt (z. B. für apt update)
resource "aws_vpc_security_group_egress_rule" "alles" {
  security_group_id = aws_security_group.server.id
  description       = "Alles nach draussen"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ---------------------------------------------------------------
# Server
# ---------------------------------------------------------------

# Data Source: Die aktuelle Ubuntu-24.04-AMI nachschlagen (nichts anlegen!)
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical, der Hersteller von Ubuntu

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }
}

# Die EC2-Instanz
resource "aws_instance" "server" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  tags = {
    Name = "${var.vorname}-server"
  }
}
