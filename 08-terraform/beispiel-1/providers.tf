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
