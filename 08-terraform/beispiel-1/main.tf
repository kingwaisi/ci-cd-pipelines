# ---------------------------------------------------------------
# Einstellungen für Terraform selbst
# ---------------------------------------------------------------
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Remote Backend: Der State liegt dann in einem S3-Bucket statt auf
  # deinem Laptop. Wird erst in Aufgabe 7 einkommentiert!
  #
  # backend "s3" {
  #   bucket       = "terraform-state-DEIN-NAME-12345"
  #   key          = "terraform-kurs/terraform.tfstate"
  #   region       = "us-east-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

# ---------------------------------------------------------------
# Provider: Mit welcher Cloud und welcher Region sprechen wir?
# ---------------------------------------------------------------
provider "aws" {
  region = "us-east-1"
}

# ---------------------------------------------------------------
# Netzwerk
# ---------------------------------------------------------------

# Das VPC: unser eigenes, abgeschottetes Netzwerk
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.vorname}-vpc"
  }
}

# Das Internet Gateway: die Tür vom VPC ins Internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.vorname}-igw"
  }
}

# Das Subnetz: ein Teilbereich des VPCs in einer Availability Zone
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.vorname}-public-subnet"
  }
}

# Die Route Table: Alles, was nicht ins VPC gehört, geht zum Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.vorname}-public-rt"
  }
}

# Die Route Table mit dem Subnetz verbinden – erst das macht es "öffentlich"
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

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
