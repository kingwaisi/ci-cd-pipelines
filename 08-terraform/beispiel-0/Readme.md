# Terraform Getting started

1. Folgenden Block kopieren und in eine `main.tf`- Datei schreiben
2. Aus dem Ordner mit der `main.tf` `terraform init`
3. `terraform apply` `terraform fmt` `terraform plan` ausführen

4. Folgendes in das Terminal eingeben, um die Credentials für euren AWS Account im Terminal zu hinterlegen (als Umgebungsvariable):

```bash
export AWS_ACCESS_KEY_ID="<deine Access Key ID>"
export AWS_SECRET_ACCESS_KEY="<dein Secret Access Key>"
```

5. `main.tf` um folgende Blöcke ergänzen:

```bash
# ---------------------------------------------------------------
# Provider: Mit welcher Cloud und welcher Region sprechen wir?
# ---------------------------------------------------------------
provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "unser-erstes-terraform-vpc"
  }
}
```

Damit legen wir ein VPC an, nachdem wir den folgenden Schritt ausgeführt haben [Mehr dazu](https://registry.terraform.io/providers/-/aws/latest/docs/resources/vpc)

6. `terraform validate`
7. `terraform plan`
8. `terraform apply` und yes eingeben auf nachfrage
9. In der AWS UI Konsole nachschauen, ob VPC erstellt wurde
10. `terraform destroy`
11. In der AWS UI Konsole nachschauen, ob VPC gelöscht wurde
