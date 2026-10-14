# Terraform: Infrastruktur als Code

In Kapitel 05 hast du dir ein VPC, ein Subnetz, eine Security Group und eine EC2-Instanz **zusammengeklickt**. Das funktioniert – aber weißt du noch genau, welche Häkchen du gesetzt hast? Könntest du dasselbe morgen noch einmal **exakt gleich** aufbauen? Und was, wenn du es zehnmal brauchst oder eine Kollegin wissen möchte, was du eigentlich angelegt hast?

In diesem Kapitel beschreibst du dieselbe Infrastruktur als **Text in einer Datei**. Das Werkzeug **Terraform** liest diese Datei und legt alles für dich in AWS an: ein **VPC** mit einem **öffentlichen Subnetz** und darin eine kleine **EC2-Instanz** mit öffentlicher IP-Adresse, auf die du dich per SSH verbindest. Am Ende räumst du mit **einem einzigen Befehl** alles wieder ab.

## Grundbegriffe

### Was ist Infrastructure as Code?

**Infrastructure as Code** (kurz **IaC**, „Infrastruktur als Code“) bedeutet: Server, Netzwerke und Firewalls werden nicht von Hand angeklickt, sondern in **Textdateien beschrieben**. Ein Programm setzt diese Beschreibung dann um.

| Von Hand in der Konsole („ClickOps“)          | Infrastructure as Code                                           |
| --------------------------------------------- | ---------------------------------------------------------------- |
| Niemand weiß genau, was eingestellt wurde     | Die Datei **ist** die Dokumentation                              |
| Zweimal dasselbe aufbauen = zweimal klicken   | Beliebig oft **wiederholbar**, immer mit demselben Ergebnis      |
| Fehler durch Vertippen und vergessene Häkchen | Änderungen werden **vorher angezeigt** und können geprüft werden |
| Keine Historie                                | Liegt in **Git**: wer hat wann was geändert?                     |
| Aufräumen: jede Ressource einzeln suchen      | **Ein Befehl** löscht alles, was angelegt wurde                  |

> **Vergleich:** Von Hand zu klicken ist wie Kochen nach Gefühl. IaC ist das aufgeschriebene **Rezept**: Jeder kann es nachkochen, und es schmeckt jedes Mal gleich.

### Was ist Terraform?

**Terraform** (von der Firma HashiCorp) ist das bekannteste IaC-Werkzeug. Es funktioniert nicht nur mit AWS, sondern auch mit Azure, Google Cloud, GitHub, Kubernetes und hunderten weiteren Diensten.

Terraform arbeitet **deklarativ** – das Prinzip kennst du aus Kapitel 07 von Kubernetes: Du beschreibst nicht die einzelnen Schritte („erst das VPC anlegen, dann das Subnetz …“), sondern den **Wunschzustand** („es soll ein VPC mit einem Subnetz geben“). Terraform vergleicht den Wunschzustand mit dem, was schon existiert, und findet selbst heraus, was zu tun ist – und in welcher Reihenfolge.

### Die wichtigsten Terraform-Begriffe

| Begriff         | Bedeutung                                                                                          | Vergleich                                  |
| --------------- | -------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **HCL**         | Die Sprache, in der Terraform-Dateien geschrieben sind (_HashiCorp Configuration Language_)        | Die Sprache des Rezepts                    |
| **`.tf`-Datei** | Eine Textdatei mit Terraform-Code. Terraform liest **alle** `.tf`-Dateien im aktuellen Ordner      | Die Rezeptkarte                            |
| **Provider**    | Ein Plugin, das Terraform beibringt, mit einem bestimmten Dienst zu sprechen (z. B. `aws`)         | Der Dolmetscher                            |
| **Resource**    | Ein Ding, das Terraform **anlegt und verwaltet** (VPC, Subnetz, Instanz …)                         | Eine Zutat, die du selbst zubereitest      |
| **Data Source** | Etwas, das Terraform nur **nachschlägt**, aber nicht anlegt (z. B. die aktuelle Ubuntu-AMI)        | Im Regal nachsehen, was schon da ist       |
| **Variable**    | Ein Wert, den man von außen einstellen kann, ohne den Code zu ändern                               | „Menge nach Personenzahl“                  |
| **Output**      | Ein Wert, den Terraform am Ende anzeigt (z. B. die öffentliche IP)                                 | Der Kassenzettel                           |
| **State**       | Terraforms **Gedächtnis**: eine Datei, in der steht, welche Ressourcen es angelegt hat             | Das Inventarbuch                           |
| **Backend**     | Der **Ort**, an dem der State gespeichert wird: lokal auf dem Laptop oder z. B. in einem S3-Bucket | Der Schrank, in dem das Inventarbuch liegt |
| **Plan**        | Die Vorschau: Was **würde** Terraform ändern?                                                      | Der Kostenvoranschlag                      |
| **Apply**       | Die Änderungen wirklich **durchführen**                                                            | Der Auftrag wird ausgeführt                |

### So sieht Terraform-Code aus

Fast alles in Terraform ist ein **Block**. Der wichtigste ist der `resource`-Block:

```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}
```

| Teil                 | Bedeutung                                                                                   |
| -------------------- | ------------------------------------------------------------------------------------------- |
| `resource`           | Die Art des Blocks: Hier wird etwas **angelegt**                                            |
| `"aws_vpc"`          | Der **Typ** der Ressource. Den gibt der Provider vor – `aws_` verrät, dass er zu AWS gehört |
| `"main"`             | Der **Name**, den **du** vergibst. Er gilt nur innerhalb von Terraform, nicht in AWS        |
| `cidr_block = "..."` | Ein **Argument**: eine Einstellung der Ressource                                            |

Über `Typ.Name.Eigenschaft` kann eine Ressource auf eine andere **verweisen**:

```hcl
resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}
```

`aws_vpc.main.id` bedeutet: „die ID des VPCs, das oben `main` heißt“. Die ID kennst du beim Schreiben noch gar nicht – AWS vergibt sie erst beim Anlegen. Terraform erkennt an diesem Verweis außerdem die **Reihenfolge**: erst das VPC, dann das Subnetz.

### Der Terraform-Ablauf

```
   Code schreiben          einmalig              Vorschau             Ausführen             Aufräumen
 ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   ┌────────────────┐   ┌───────────────────┐
 │  *.tf-Dateien  │──▶│ terraform init │──▶│ terraform plan │──▶│terraform apply │──▶│ terraform destroy │
 └────────────────┘   └────────────────┘   └────────────────┘   └────────────────┘   └───────────────────┘
                       Provider laden       Was würde sich       Änderungen            Alles wieder
                                            ändern?              durchführen           löschen
                                                   ▲                    │
                                                   └── Code ändern ◀────┘
```

### Was ist der State?

Woher weiß Terraform, dass das VPC `vpc-0a1b2c…` in AWS zu dem Block `aws_vpc.main` in deiner Datei gehört? Es merkt sich das im **State**, einer Datei namens `terraform.tfstate`.

Bei jedem `plan` und `apply` vergleicht Terraform drei Dinge:

```
   Dein Code (.tf)              State (terraform.tfstate)            Die echte Welt (AWS)
  „So soll es sein“       „Das habe ich zuletzt angelegt“         „So ist es wirklich“
```

Ohne State wüsste Terraform nicht, welche Ressourcen ihm „gehören“ – es würde alles noch einmal anlegen und könnte nichts aufräumen. Deshalb gilt:

- Den State **niemals löschen**, solange die Ressourcen noch existieren
- Den State **niemals von Hand bearbeiten**
- Den State **nicht in Git committen** – er kann Passwörter und andere Geheimnisse im Klartext enthalten

Zunächst liegt der State **lokal** in deinem Projektordner. In Aufgabe 7 ziehst du ihn in ein **Remote Backend** um – einen S3-Bucket in AWS.

### Das Gesamtbild

```
   Dein Laptop (WSL)                                AWS Cloud (us-east-1)
 ┌────────────────────────┐              ┌──────────────────────────────────────────────┐
 │ main.tf                │              │ VPC 10.0.0.0/16                              │
 │ variables.tf           │              │                                              │
 │ outputs.tf             │   AWS-API    │  Internet Gateway ◀── Route Table            │
 │      │                 │─────────────▶│         │                                    │
 │      ▼ terraform apply │              │ ┌───────▼──────────────────────────────────┐ │
 │ terraform.tfstate      │              │ │ Öffentliches Subnetz 10.0.1.0/24         │ │
 │ (das Gedächtnis)       │              │ │  ┌────────────────────────────────────┐  │ │
 │                        │              │ │  │ Security Group (Port 22)           │  │ │
 │ Terminal ──────────────┼──── SSH ────▶│ │  │  EC2-Instanz (Ubuntu, t3.micro)    │  │ │
 │                        │              │ │  └────────────────────────────────────┘  │ │
 └────────────────────────┘              │ └──────────────────────────────────────────┘ │
                                         └──────────────────────────────────────────────┘
```

Das ist genau der Aufbau aus Kapitel 05 – nur dass diesmal **Terraform** klickt und nicht du.

## Voraussetzungen

- Zugang zur **AWS-Konsole** (eigener Account oder Zugangsdaten aus dem Kurs)
- **WSL mit Ubuntu** (siehe Kapitel 01) – auf macOS oder Linux funktioniert alles genauso im normalen Terminal
- **VS Code** – empfehlenswert ist die Erweiterung **HashiCorp Terraform** (farbige Darstellung und Autovervollständigung für `.tf`-Dateien)
- Du weißt, was **VPC**, **Subnetz**, **Security Group** und **Schlüsselpaar** sind und wie man sich per **SSH** verbindet (siehe Kapitel 05)

> **Kosten:** VPC, Subnetz, Internet Gateway und Security Group kosten nichts. Die Instanz (`t3.micro`) und ihre öffentliche IP-Adresse kosten zusammen etwa **1–2 Cent pro Stunde** (bzw. sind im Free Tier enthalten). Für eine Unterrichtsstunde ist das egal – **vergiss aber nicht, am Ende aufzuräumen!**

## Überblick: Was machst du in diesem Kapitel?

| Aufgabe            | Inhalt                                                    | Ergebnis                                           |
| ------------------ | --------------------------------------------------------- | -------------------------------------------------- |
| **1**              | Terraform und die AWS CLI installieren, Zugangsdaten      | `aws sts get-caller-identity` zeigt deinen Account |
| **2**              | SSH-Schlüsselpaar **von Hand** in der AWS-Konsole anlegen | `terraform-kurs-key.pem` liegt in `~/.ssh`         |
| **3**              | Projekt anlegen, Provider einrichten, `terraform init`    | Terraform ist bereit                               |
| **4**              | **VPC** mit öffentlichem Subnetz                          | 5 Ressourcen in AWS, sichtbar in der Konsole       |
| **5**              | **Security Group** und **EC2-Instanz**                    | Du bist per SSH auf deinem Server                  |
| **6**              | **Variablen** – und eine Änderung ausrollen               | Alle Ressourcen tragen deinen Namen                |
| **7**              | Das **Remote Backend** einkommentieren                    | Der State liegt in einem S3-Bucket                 |
| Zusatzaufgaben 1–4 | nginx per `user_data`, SSH absichern, Schlüssel, Drift    | Für alle, die schneller fertig sind                |

Die Aufgaben bauen **aufeinander auf** – bearbeite sie der Reihe nach.

---

## Aufgabe 1: Terraform und die AWS CLI installieren

Du brauchst zwei Programme:

- **terraform** – liest deine `.tf`-Dateien und legt die Infrastruktur an
- **aws** (die AWS CLI) – damit hinterlegst du deine Zugangsdaten und kannst prüfen, ob sie funktionieren

### Schritt 1: Terraform installieren

```bash
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

- Zeile 1: den **Signaturschlüssel** von HashiCorp herunterladen. Damit prüft `apt`, dass die Pakete wirklich von HashiCorp stammen
- Zeile 2: die **Paketquelle** von HashiCorp eintragen – Terraform ist in den normalen Ubuntu-Quellen nicht enthalten
- Zeile 3: die Paketliste aktualisieren und Terraform installieren

Prüfen:

```bash
terraform version
```

**Das solltest du sehen** (die Versionsnummer kann bei dir neuer sein):

```
Terraform v1.16.4
on linux_amd64
```

> Diese Anleitung setzt **Terraform 1.10 oder neuer** voraus.

### Schritt 2: Die AWS CLI installieren

```bash
cd ~
sudo apt install -y unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip -q awscliv2.zip
sudo ./aws/install
rm -rf aws awscliv2.zip
```

> **ARM-Prozessor?** Zeigt `uname -m` bei dir `aarch64` an, ersetze in Zeile 3 `x86_64` durch `aarch64`.

Prüfen:

```bash
aws --version
```

```
aws-cli/2.27.62 Python/3.13.5 Linux/6.6.87.2-microsoft-standard-WSL2 exe/x86_64.ubuntu.24
```

> **macOS:** Mit [Homebrew](https://brew.sh) geht beides in zwei Befehlen: `brew tap hashicorp/tap` und `brew install hashicorp/tap/terraform awscli`.

### Schritt 3: Einen Access Key erstellen

In der Konsole meldest du dich mit Benutzername und Passwort an. Programme wie Terraform verwenden stattdessen einen **Access Key**. Er besteht aus zwei Teilen:

| Teil                  | Beispiel                                   | Entspricht        |
| --------------------- | ------------------------------------------ | ----------------- |
| **Access Key ID**     | `AKIAIOSFODNN7EXAMPLE`                     | dem Benutzernamen |
| **Secret Access Key** | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | dem Passwort      |

> Hast du im Kurs bereits einen Access Key bekommen? Dann weiter mit Schritt 4.

1. In der [AWS-Konsole](https://console.aws.amazon.com) oben in die Suche `IAM` eingeben und den Dienst öffnen
2. Links auf **Users** klicken und deinen Benutzer auswählen
3. Reiter **Security credentials** → im Bereich **Access keys** auf **Create access key**
4. Als Anwendungsfall **Command Line Interface (CLI)** auswählen, das Häkchen zur Bestätigung setzen, **Next** → **Create access key**
5. Die Seite **offen lassen** – den Secret Access Key zeigt AWS **nur dieses eine Mal** an

> **Achtung:** Ein Access Key ist so mächtig wie dein Passwort. Wer ihn hat, kann in deinem Account Server starten – auf **deine Rechnung**. **Niemals** in eine `.tf`-Datei schreiben, niemals committen, niemals in einen Chat kopieren!

### Schritt 4: Die Zugangsdaten hinterlegen

```bash
aws configure
```

Der Befehl stellt vier Fragen:

```
AWS Access Key ID [None]: <deine Access Key ID>
AWS Secret Access Key [None]: <dein Secret Access Key>
Default region name [None]: us-east-1
Default output format [None]: json
```

Die Daten landen in der Datei `~/.aws/credentials` – also **außerhalb** deines Projektordners. Terraform findet sie dort automatisch.

#### Alternative: Nur temporär im Terminal (Umgebungsvariablen)

Du willst nichts dauerhaft auf der Festplatte speichern? Dann setzt du die Zugangsdaten nur für die **aktuelle Terminal-Sitzung**:

**macOS / Linux (bash, zsh):**

```bash
export AWS_ACCESS_KEY_ID="<deine Access Key ID>"
export AWS_SECRET_ACCESS_KEY="<dein Secret Access Key>"
export AWS_DEFAULT_REGION="us-east-1"
```

**Windows (PowerShell):**

```powershell
$env:AWS_ACCESS_KEY_ID="<deine Access Key ID>"
$env:AWS_SECRET_ACCESS_KEY="<dein Secret Access Key>"
$env:AWS_DEFAULT_REGION="us-east-1"
```

Terraform und die AWS CLI lesen diese Variablen automatisch – sie haben sogar **Vorrang** vor `~/.aws/credentials`.

> **Gut zu wissen:** Die Variablen gelten nur in **diesem einen** Terminal-Fenster. Schließt du es oder öffnest ein neues, musst du sie erneut setzen. Prüfen kannst du sie mit `echo $AWS_ACCESS_KEY_ID` (PowerShell: `echo $env:AWS_ACCESS_KEY_ID`).

### Schritt 5: Prüfen, ob die Anmeldung klappt

```bash
aws sts get-caller-identity
```

**Das solltest du sehen** (mit deinen eigenen Werten):

```json
{
  "UserId": "AIDAEXAMPLEEXAMPLE123",
  "Account": "123456789012",
  "Arn": "arn:aws:iam::123456789012:user/dein-benutzer"
}
```

Der Befehl fragt AWS: „Wer bin ich?“ Kommt hier eine Antwort, funktioniert die Anmeldung – und damit auch Terraform.

---

## Aufgabe 2: Das SSH-Schlüsselpaar von Hand anlegen

Fast alles legt in diesem Kapitel Terraform an. **Eine Ausnahme machen wir bewusst:** Das Schlüsselpaar für SSH erstellst du selbst in der Konsole. So bleibt dein **privater Schlüssel** bei dir und taucht weder im Code noch im State auf. Terraform bekommt später nur den **Namen** des Schlüsselpaars genannt.

### Schritt 1: Schlüsselpaar in der Konsole erstellen

1. In der AWS-Konsole oben rechts die **Region** auf **US East (N. Virginia) us-east-1** stellen
2. Den Dienst **EC2** öffnen
3. Links im Menü unter **Network & Security** auf **Key Pairs** klicken
4. Oben rechts **Create key pair**
5. **Name**: `terraform-kurs-key`
6. **Key pair type**: `ED25519`
7. **Private key file format**: `.pem`
8. Auf **Create key pair** klicken – die Datei `terraform-kurs-key.pem` wird in deinen **Downloads**-Ordner geladen

> **Wichtig:** Ein Schlüsselpaar gibt es nur in der **Region**, in der es erstellt wurde. Legst du es versehentlich in einer anderen Region an, findet Terraform es später nicht.

> **Mehrere Personen in einem AWS-Account?** Dann muss jeder Name eindeutig sein. Hänge deinen Vornamen an (`terraform-kurs-key-anna`) und verwende diesen Namen überall, wo in dieser Anleitung `terraform-kurs-key` steht.

### Schritt 2: Schlüssel in die WSL kopieren und schützen

Das kennst du aus Kapitel 05:

```bash
mkdir -p ~/.ssh
cp /mnt/c/Users/<Windows-Benutzername>/Downloads/terraform-kurs-key.pem ~/.ssh/
chmod 400 ~/.ssh/terraform-kurs-key.pem
```

Prüfen:

```bash
ls -l ~/.ssh/terraform-kurs-key.pem
```

**Das solltest du sehen:** eine Zeile, die mit `-r--------` beginnt – nur du darfst die Datei lesen.

---

## Aufgabe 3: Das Projekt anlegen und Terraform initialisieren

### Schritt 1: Projektordner anlegen

```bash
mkdir ~/terraform-kurs
cd ~/terraform-kurs
code .
```

VS Code öffnet sich mit dem leeren Ordner `terraform-kurs`.

### Schritt 2: Die Datei `main.tf` anlegen

Lege in VS Code die Datei `main.tf` an:

```hcl
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
```

| Abschnitt            | Bedeutung                                                                                                      |
| -------------------- | -------------------------------------------------------------------------------------------------------------- |
| `terraform { }`      | Einstellungen für Terraform selbst                                                                             |
| `required_version`   | Welche Terraform-Version mindestens nötig ist                                                                  |
| `required_providers` | Welche Provider gebraucht werden. `~> 6.0` bedeutet: jede Version `6.x`, aber nicht `7.0`                      |
| `# backend "s3"`     | Zeilen mit `#` sind **Kommentare** – Terraform ignoriert sie. Dieser Block bleibt bis Aufgabe 7 auskommentiert |
| `provider "aws" { }` | Einstellungen für den AWS-Provider: Alle Ressourcen landen in der Region `us-east-1`                           |

> **Wo stehen die Zugangsdaten?** Nirgends in dieser Datei – und das ist Absicht. Der Provider liest sie aus `~/.aws/credentials` (Aufgabe 1). So kann die Datei gefahrlos in Git landen.

### Schritt 3: Die Datei `.gitignore` anlegen

Lege im selben Ordner die Datei `.gitignore` an (mit Punkt am Anfang):

```
# Heruntergeladene Provider – werden mit "terraform init" neu geholt
.terraform/

# Der State kann Geheimnisse enthalten und gehört nicht in Git
*.tfstate
*.tfstate.*

# Private Schlüssel
*.pem
```

Auch wenn du heute vielleicht gar kein Git-Repository anlegst: Gewöhne dir an, diese Datei **als Erstes** zu erstellen.

### Schritt 4: Terraform initialisieren

```bash
terraform init
```

**Das solltest du sehen** (gekürzt):

```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 6.0"...
- Installing hashicorp/aws v6.68.0...
- Installed hashicorp/aws v6.68.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

`init` hat den AWS-Provider heruntergeladen. Schau nach, was im Ordner dazugekommen ist:

```bash
ls -a
```

```
.  ..  .gitignore  .terraform  .terraform.lock.hcl  main.tf
```

| Datei / Ordner        | Inhalt                                                                            | In Git?  |
| --------------------- | --------------------------------------------------------------------------------- | -------- |
| `.terraform/`         | Der heruntergeladene Provider (mehrere hundert MB!)                               | **Nein** |
| `.terraform.lock.hcl` | Merkt sich die **genaue** Provider-Version, damit alle im Team dieselbe verwenden | **Ja**   |

> `terraform init` führst du **einmal pro Projektordner** aus – und immer dann erneut, wenn du etwas am Provider oder am Backend änderst.

### Schritt 5: Zwei nützliche Helfer

```bash
terraform fmt
terraform validate
```

- `terraform fmt` – rückt deinen Code einheitlich ein und richtet die `=`-Zeichen aus. Gibt die Namen der Dateien aus, die es verändert hat (oder nichts, wenn schon alles ordentlich war)
- `terraform validate` – prüft, ob der Code **syntaktisch** stimmt, ohne mit AWS zu sprechen

**Das solltest du sehen:**

```
Success! The configuration is valid.
```

Führe beide Befehle ab jetzt nach **jeder** Änderung aus – sie finden Tippfehler in Sekunden.

---

## Aufgabe 4: Das VPC mit einem öffentlichen Subnetz

Jetzt entsteht das Netzwerk. Damit ein Subnetz **öffentlich** ist, braucht es fünf Bausteine – dieselben, die du in Kapitel 05 von Hand angelegt hast:

| Baustein                  | Terraform-Typ                 | Aufgabe                                                   |
| ------------------------- | ----------------------------- | --------------------------------------------------------- |
| **VPC**                   | `aws_vpc`                     | Das abgeschottete Netzwerk (das Grundstück)               |
| **Internet Gateway**      | `aws_internet_gateway`        | Die Tür vom VPC ins Internet                              |
| **Subnetz**               | `aws_subnet`                  | Ein Teilbereich des VPCs (ein Gebäude auf dem Grundstück) |
| **Route Table**           | `aws_route_table`             | Der Wegweiser: „Ins Internet geht es durch das Gateway“   |
| **Route-Table-Zuordnung** | `aws_route_table_association` | Hängt den Wegweiser an das Subnetz                        |

### Schritt 1: Die Ressourcen schreiben

Füge **am Ende** deiner `main.tf` hinzu:

```hcl
# ---------------------------------------------------------------
# Netzwerk
# ---------------------------------------------------------------

# Das VPC: unser eigenes, abgeschottetes Netzwerk
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "terraform-kurs-vpc"
  }
}

# Das Internet Gateway: die Tür vom VPC ins Internet
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "terraform-kurs-igw"
  }
}

# Das Subnetz: ein Teilbereich des VPCs in einer Availability Zone
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "terraform-kurs-public-subnet"
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
    Name = "terraform-kurs-public-rt"
  }
}

# Die Route Table mit dem Subnetz verbinden – erst das macht es "öffentlich"
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

| Argument                         | Bedeutung                                                                                        |
| -------------------------------- | ------------------------------------------------------------------------------------------------ |
| `cidr_block = "10.0.0.0/16"`     | Der Adressbereich des VPCs: `10.0.0.0` bis `10.0.255.255` (rund 65.000 Adressen)                 |
| `cidr_block = "10.0.1.0/24"`     | Der Adressbereich des Subnetzes: `10.0.1.0` bis `10.0.1.255` – ein Ausschnitt aus dem VPC        |
| `availability_zone`              | In welchem Rechenzentrum der Region das Subnetz liegt                                            |
| `map_public_ip_on_launch = true` | Instanzen in diesem Subnetz bekommen automatisch eine öffentliche IP (**Auto-assign public IP**) |
| `route { ... }`                  | Die Route `0.0.0.0/0` („alle Adressen“) zeigt auf das Internet Gateway                           |
| `tags = { Name = "..." }`        | Der Name, unter dem du die Ressource in der Konsole wiederfindest                                |
| `vpc_id = aws_vpc.main.id`       | Ein **Verweis**: „Gehört zu dem VPC, das oben `main` heißt“                                      |

Formatieren und prüfen:

```bash
terraform fmt
terraform validate
```

### Schritt 2: Die Vorschau – `terraform plan`

```bash
terraform plan
```

Terraform zeigt jetzt **sehr ausführlich**, was es tun würde – **ohne** etwas zu ändern. Die Ausgabe ist lang, beginnt mit einer Legende und endet mit einer Zusammenfassung. **Das solltest du sehen** (stark gekürzt):

```
Terraform will perform the following actions:

  # aws_internet_gateway.main will be created
  + resource "aws_internet_gateway" "main" {
      + id       = (known after apply)
      + tags     = {
          + "Name" = "terraform-kurs-igw"
        }
      + vpc_id   = (known after apply)
    }

  # aws_vpc.main will be created
  + resource "aws_vpc" "main" {
      + cidr_block           = "10.0.0.0/16"
      + enable_dns_hostnames = true
      + id                   = (known after apply)
      ...
    }

  ...

Plan: 5 to add, 0 to change, 0 to destroy.
```

So liest du einen Plan:

| Zeichen | Bedeutung                                                                  |
| ------- | -------------------------------------------------------------------------- |
| `+`     | Wird **neu angelegt**                                                      |
| `~`     | Wird **geändert**, die Ressource bleibt bestehen (_update in-place_)       |
| `-`     | Wird **gelöscht**                                                          |
| `-/+`   | Wird **gelöscht und neu angelegt** (_replace_) – Vorsicht, Daten sind weg! |

`(known after apply)` bedeutet: Diesen Wert vergibt AWS erst beim Anlegen, zum Beispiel die ID des VPCs.

**Die wichtigste Zeile steht ganz unten:** `Plan: 5 to add, 0 to change, 0 to destroy.` Lies sie **jedes Mal**, bevor du weitermachst. Steht dort plötzlich „to destroy“, obwohl du nur etwas hinzufügen wolltest, stimmt etwas nicht.

### Schritt 3: Ausführen – `terraform apply`

```bash
terraform apply
```

Terraform zeigt den Plan noch einmal und fragt dann nach:

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Tippe `yes` (ausgeschrieben!) und drücke `Enter`. **Das solltest du sehen** (IDs und Zeiten sind bei dir anders):

```
aws_vpc.main: Creating...
aws_vpc.main: Still creating... [00m10s elapsed]
aws_vpc.main: Creation complete after 13s [id=vpc-0a1b2c3d4e5f67890]
aws_internet_gateway.main: Creating...
aws_subnet.public: Creating...
aws_internet_gateway.main: Creation complete after 1s [id=igw-0a1b2c3d4e5f67890]
aws_route_table.public: Creating...
aws_route_table.public: Creation complete after 2s [id=rtb-0a1b2c3d4e5f67890]
aws_subnet.public: Creation complete after 11s [id=subnet-0a1b2c3d4e5f67890]
aws_route_table_association.public: Creating...
aws_route_table_association.public: Creation complete after 1s [id=rtbassoc-0a1b2c3d4e5f67890]

Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

Achte auf die **Reihenfolge**: Zuerst das VPC, danach Internet Gateway und Subnetz **gleichzeitig**, ganz am Schluss die Zuordnung. Du hast diese Reihenfolge nirgends festgelegt – Terraform hat sie aus den **Verweisen** (`aws_vpc.main.id` usw.) abgeleitet.

### Schritt 4: In der Konsole nachsehen

Öffne in der AWS-Konsole den Dienst **VPC** (Region **us-east-1**!) → links **Your VPCs**. Dort steht `terraform-kurs-vpc`. Klicke es an und öffne den Reiter **Resource map**: Du siehst Subnetz, Route Table und Internet Gateway, verbunden durch Linien.

**Das alles ist in gut 20 Sekunden entstanden – ohne einen einzigen Klick.**

### Schritt 5: Ein Blick in den State

```bash
ls
terraform state list
```

**Das solltest du sehen:**

```
main.tf  terraform.tfstate

aws_internet_gateway.main
aws_route_table.public
aws_route_table_association.public
aws_subnet.public
aws_vpc.main
```

Im Ordner liegt jetzt die Datei `terraform.tfstate`. `terraform state list` zeigt, welche Ressourcen Terraform darin verwaltet. Details zu einer einzelnen Ressource:

```bash
terraform state show aws_vpc.main
```

Hier steht jetzt auch die echte ID (`id = "vpc-0…"`), die beim Plan noch `(known after apply)` war.

### Schritt 6: Noch einmal `apply`?

Führe `terraform apply` einfach **noch einmal** aus.

**Das solltest du sehen:**

```
No changes. Your infrastructure matches the configuration.

Apply complete! Resources: 0 added, 0 changed, 0 destroyed.
```

Code, State und AWS stimmen überein, also gibt es nichts zu tun. Das kennst du von `kubectl apply` (`unchanged`): Du kannst den Befehl beliebig oft ausführen, es entsteht **kein** zweites VPC.

---

## Aufgabe 5: Security Group und EC2-Instanz

### Schritt 1: Die Security Group

Füge am Ende der `main.tf` hinzu:

```hcl
# ---------------------------------------------------------------
# Firewall
# ---------------------------------------------------------------

resource "aws_security_group" "server" {
  name        = "terraform-kurs-sg"
  description = "Firewall fuer den Terraform-Kurs-Server"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "terraform-kurs-sg"
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
```

- Die Security Group selbst ist zunächst eine **leere Hülle**. Jede Regel ist eine **eigene Ressource**, die auf die Gruppe verweist
- **ingress** = eingehend (von außen zur Instanz), **egress** = ausgehend (von der Instanz nach außen)
- `from_port` und `to_port` beschreiben einen **Bereich** von Ports. Für genau einen Port steht zweimal dieselbe Zahl da
- `ip_protocol = "-1"` bedeutet „alle Protokolle und alle Ports“

> **Warum eine Regel für ausgehenden Verkehr?** In der Konsole legt AWS sie stillschweigend für dich an. Terraform tut **nur**, was im Code steht. Ohne diese Regel könnte deine Instanz später nicht einmal `apt update` ausführen.

> **Warum `fuer` und `draussen` statt „für“ und „draußen“?** AWS erlaubt in der Beschreibung einer Security Group keine Umlaute und kein ß. In Kommentaren (`#`) und in Tags sind sie kein Problem.

> **`0.0.0.0/0` bei SSH** ist bequem, aber nicht sicher – das weißt du aus Kapitel 05. Wie du es besser machst, zeigt Zusatzaufgabe 2.

### Schritt 2: Die AMI nachschlagen und die Instanz beschreiben

Jede Instanz braucht eine **AMI** (die Vorlage mit dem Betriebssystem). Die ID sieht so aus: `ami-0a1b2c3d4e5f67890`. Sie ist in jeder Region anders und ändert sich mit jedem Ubuntu-Update. Statt sie abzutippen, lässt du Terraform **nachschlagen** – mit einer **Data Source**.

Füge am Ende der `main.tf` hinzu:

```hcl
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
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.server.id]
  associate_public_ip_address = true
  key_name                    = "terraform-kurs-key"

  tags = {
    Name = "terraform-kurs-server"
  }
}
```

| Argument                             | Bedeutung                                                                                        | In Kapitel 05 war das …             |
| ------------------------------------ | ------------------------------------------------------------------------------------------------ | ----------------------------------- |
| `ami = data.aws_ami.ubuntu.id`       | Die ID der AMI, die die Data Source gefunden hat. Verweise auf Data Sources beginnen mit `data.` | „Ubuntu Server 24.04 LTS“ anklicken |
| `instance_type = "t3.micro"`         | 2 CPUs, 1 GB Arbeitsspeicher – klein und günstig                                                 | Schritt 4: Instanztyp               |
| `subnet_id`                          | In welches Subnetz die Instanz kommt – unser öffentliches                                        | Schritt 6: Subnet                   |
| `vpc_security_group_ids = [ ... ]`   | Welche Security Groups gelten. Die eckigen Klammern bedeuten **Liste** – es könnten mehrere sein | Schritt 7: Security Group           |
| `associate_public_ip_address = true` | Die Instanz bekommt eine öffentliche IP                                                          | Schritt 6: Auto-assign public IP    |
| `key_name`                           | Der **Name** des Schlüsselpaars aus Aufgabe 2. Muss **exakt** so heißen wie in der Konsole       | Schritt 5: Key pair                 |

### Schritt 3: Outputs anlegen

Nach dem Anlegen willst du die öffentliche IP wissen, ohne in der Konsole zu suchen. Dafür gibt es **Outputs**. Lege eine **neue Datei** `outputs.tf` an:

```hcl
output "public_ip" {
  description = "Die öffentliche IP-Adresse der Instanz"
  value       = aws_instance.server.public_ip
}

output "ssh_befehl" {
  description = "Fertiger Befehl zum Verbinden"
  value       = "ssh -i ~/.ssh/terraform-kurs-key.pem ubuntu@${aws_instance.server.public_ip}"
}
```

Mit `${ ... }` setzt du einen Wert **mitten in einen Text** ein – hier die IP-Adresse in den SSH-Befehl.

> **Warum eine zweite Datei?** Terraform liest **alle** `.tf`-Dateien im Ordner und behandelt sie wie eine einzige große Datei. Die Aufteilung dient nur der Übersicht. Üblich sind `main.tf`, `variables.tf` und `outputs.tf`.

### Schritt 4: Plan und Apply

```bash
terraform fmt
terraform validate
terraform plan
```

**Das solltest du am Ende sehen:**

```
Plan: 4 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + public_ip  = (known after apply)
  + ssh_befehl = (known after apply)
```

**Vier** neue Ressourcen: die Security Group, zwei Regeln, die Instanz. Die fünf Netzwerk-Ressourcen aus Aufgabe 4 tauchen nicht auf – sie existieren schon und haben sich nicht geändert. Suche im Plan nach der Zeile, die mit `+ ami` beginnt: Dort steht die AMI-ID, die die Data Source gefunden hat.

```bash
terraform apply
```

Mit `yes` bestätigen. **Das solltest du am Ende sehen:**

```
aws_instance.server: Creating...
aws_instance.server: Still creating... [00m10s elapsed]
aws_instance.server: Creation complete after 13s [id=i-0a1b2c3d4e5f67890]

Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

public_ip = "3.91.45.67"
ssh_befehl = "ssh -i ~/.ssh/terraform-kurs-key.pem ubuntu@3.91.45.67"
```

Die Outputs kannst du dir jederzeit wieder anzeigen lassen:

```bash
terraform output
terraform output -raw public_ip
```

### Schritt 5: Per SSH verbinden 🎉

Warte nach dem `apply` etwa **30 Sekunden** – die Instanz „läuft“ zwar schon, aber Ubuntu fährt noch hoch. Kopiere dann den Befehl aus dem Output `ssh_befehl` und führe ihn aus:

```bash
ssh -i ~/.ssh/terraform-kurs-key.pem ubuntu@<Public-IP>
```

Die Sicherheitsfrage mit `yes` bestätigen. **Das solltest du sehen:** Die Eingabezeile ändert sich zu

```
ubuntu@ip-10-0-1-123:~$
```

Schau genau hin: `ip-10-0-1-…` – die interne Adresse stammt aus **deinem** Subnetz `10.0.1.0/24`, das du ein paar Zeilen weiter oben in der `main.tf` festgelegt hast.

Teste, ob der Weg ins Internet funktioniert (Internet Gateway, Route Table und Egress-Regel spielen zusammen):

```bash
curl -s https://checkip.amazonaws.com
```

**Das solltest du sehen:** die öffentliche IP deiner Instanz. Mit `exit` verlässt du den Server wieder.

Sieh dir die Instanz auch in der Konsole an (**EC2** → **Instances**): Sie heißt `terraform-kurs-server`, läuft in deinem VPC und verwendet dein Schlüsselpaar.

> **Musterlösung:** Alle Dateien dieses Kapitels (Stand nach Aufgabe 6) findest du im Ordner [`beispiel/`](./beispiel/).

---

## Aufgabe 6: Variablen – und eine Änderung ausrollen

Im Code stehen einige Werte fest drin: der Instanztyp, der Name des Schlüsselpaars, und alle Ressourcen heißen `terraform-kurs-…`. Möchte deine Sitznachbarin denselben Code verwenden, müsste sie ihn an vielen Stellen ändern. Besser: **Variablen**.

### Schritt 1: Variablen deklarieren

Lege eine neue Datei `variables.tf` an:

```hcl
variable "vorname" {
  description = "Dein Vorname – wird den Namen aller Ressourcen vorangestellt"
  type        = string
}

variable "instance_type" {
  description = "Die Größe der EC2-Instanz"
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Name des Schlüsselpaars, das du in der AWS-Konsole angelegt hast"
  type        = string
  default     = "terraform-kurs-key"
}
```

- `type = string` – die Variable enthält einen Text
- `default` – der Wert, der gilt, wenn niemand etwas anderes angibt. `vorname` hat **keinen** Standardwert: Terraform muss ihn von dir bekommen

### Schritt 2: Variablen verwenden

Auf eine Variable greifst du mit `var.<Name>` zu. Ändere in der `main.tf` **alle sechs** `Name`-Tags sowie Instanztyp und Schlüsselname:

| Ressource                   | Vorher                                  | Nachher                                 |
| --------------------------- | --------------------------------------- | --------------------------------------- |
| `aws_vpc.main`              | `Name = "terraform-kurs-vpc"`           | `Name = "${var.vorname}-vpc"`           |
| `aws_internet_gateway.main` | `Name = "terraform-kurs-igw"`           | `Name = "${var.vorname}-igw"`           |
| `aws_subnet.public`         | `Name = "terraform-kurs-public-subnet"` | `Name = "${var.vorname}-public-subnet"` |
| `aws_route_table.public`    | `Name = "terraform-kurs-public-rt"`     | `Name = "${var.vorname}-public-rt"`     |
| `aws_security_group.server` | `Name = "terraform-kurs-sg"` (im Tag!)  | `Name = "${var.vorname}-sg"`            |
| `aws_instance.server`       | `Name = "terraform-kurs-server"`        | `Name = "${var.vorname}-server"`        |
| `aws_instance.server`       | `instance_type = "t3.micro"`            | `instance_type = var.instance_type`     |
| `aws_instance.server`       | `key_name = "terraform-kurs-key"`       | `key_name = var.key_name`               |

> **Achtung bei der Security Group:** Ändere nur den **Tag** `Name`, **nicht** das Argument `name = "terraform-kurs-sg"` zwei Zeilen darüber. Warum, erfährst du unten bei „Zum Knobeln“.

Und in der `outputs.tf` den SSH-Befehl:

```hcl
  value       = "ssh -i ~/.ssh/${var.key_name}.pem ubuntu@${aws_instance.server.public_ip}"
```

Steht eine Variable **allein**, schreibst du `var.instance_type`. Steht sie **in einem Text**, brauchst du `"${var.vorname}-vpc"`.

### Schritt 3: Einen Wert übergeben

```bash
terraform plan
```

Terraform bleibt stehen und fragt:

```
var.vorname
  Dein Vorname – wird den Namen aller Ressourcen vorangestellt

  Enter a value:
```

Brich mit `Strg + C` ab – das jedes Mal einzutippen wäre lästig. Lege stattdessen die Datei `terraform.tfvars` an:

```hcl
vorname = "anna"
```

Trage deinen eigenen Vornamen ein (klein geschrieben, ohne Leerzeichen). Eine Datei mit genau diesem Namen liest Terraform **automatisch**.

| Datei              | Inhalt                                                   |
| ------------------ | -------------------------------------------------------- |
| `variables.tf`     | **Welche** Variablen gibt es? (Name, Typ, Standardwert)  |
| `terraform.tfvars` | **Welche Werte** sollen sie in **diesem** Projekt haben? |

### Schritt 4: Die Änderung ansehen und ausrollen

```bash
terraform plan
```

**Das solltest du sehen** (gekürzt):

```
  # aws_instance.server will be updated in-place
  ~ resource "aws_instance" "server" {
        id            = "i-0a1b2c3d4e5f67890"
      ~ tags          = {
          ~ "Name" = "terraform-kurs-server" -> "anna-server"
        }
        # (38 unchanged attributes hidden)
    }

  ...

Plan: 0 to add, 6 to change, 0 to destroy.
```

Das Zeichen `~` und der Pfeil `->` zeigen: Die Ressource **bleibt bestehen**, nur der Name ändert sich von alt zu neu. Instanztyp und Schlüsselname tauchen gar nicht auf – die Werte sind dieselben geblieben, sie kommen jetzt nur aus einer Variable.

```bash
terraform apply
```

Mit `yes` bestätigen. **Das solltest du am Ende sehen:**

```
Apply complete! Resources: 0 added, 6 changed, 0 destroyed.
```

Lade die Konsole neu: VPC, Subnetz und Instanz tragen jetzt deinen Namen. Die öffentliche IP ist **dieselbe** geblieben – die Instanz wurde nicht neu erstellt.

**Zum Knobeln:** Ändere in der Security Group testweise das Argument `name = "terraform-kurs-sg"` in `name = "test"` und führe **nur** `terraform plan` aus (**nicht** `apply`!). Welches Zeichen steht jetzt vor der Security Group, und was steht in der letzten Zeile? Mache die Änderung danach wieder rückgängig.

<details>
<summary>Lösung</summary>

Vor der Security Group steht `-/+` und der Hinweis `must be replaced`, hinter dem Namen `# forces replacement`. Die letzte Zeile lautet `Plan: 3 to add, 1 to change, 3 to destroy.`

Den Namen einer Security Group kann man bei AWS nachträglich **nicht ändern**. Terraform müsste sie deshalb **löschen und neu anlegen** – samt ihrer beiden Regeln. Die Instanz würde auf die neue Gruppe umgestellt (`1 to change`).

Manche Änderungen sind also harmlos (`~`), andere ersetzen die Ressource (`-/+`). Welche das sind, verrät dir der Plan. **Deshalb liest man ihn, bevor man `yes` tippt.**

</details>

---

## Aufgabe 7: Das Remote Backend einkommentieren

Im Moment liegt der State als `terraform.tfstate` auf deinem Laptop. Das hat Nachteile:

- Geht dein Laptop kaputt, ist der State weg – und Terraform „vergisst“, was es angelegt hat
- Arbeitet ihr zu zweit am selben Projekt, hat jeder einen **eigenen** State. Chaos ist garantiert
- Führen zwei Personen gleichzeitig `apply` aus, bemerkt das niemand

Ein **Remote Backend** löst das: Der State liegt an einem **zentralen Ort**, auf den alle zugreifen. Bei AWS ist das üblicherweise ein **S3-Bucket** (S3 ist der Dateispeicher von AWS).

```
          Vorher                                    Nachher
 ┌──────────────────────┐              ┌─────────────────┐      ┌──────────────────────┐
 │ Dein Laptop          │              │ Dein Laptop     │      │ S3-Bucket            │
 │  main.tf             │              │  main.tf        │─────▶│  terraform.tfstate   │
 │  terraform.tfstate   │              │                 │      │  (+ ältere Versionen)│
 └──────────────────────┘              └─────────────────┘      └──────────────────────┘
```

### Schritt 1: Den S3-Bucket anlegen

Der Bucket muss existieren, **bevor** Terraform seinen State hineinlegen kann. Deshalb legst du ihn – wie das Schlüsselpaar – **von Hand** an, diesmal über die AWS CLI.

Der Name eines Buckets muss **weltweit eindeutig** sein (über alle AWS-Kunden hinweg!). Hänge deshalb deinen Namen und ein paar zufällige Ziffern an. Erlaubt sind nur Kleinbuchstaben, Ziffern und Bindestriche.

```bash
aws s3api create-bucket --bucket terraform-state-<dein-name>-<zahl> --region us-east-1
```

Beispiel: `aws s3api create-bucket --bucket terraform-state-anna-48213 --region us-east-1`

**Das solltest du sehen:**

```json
{
  "Location": "/terraform-state-anna-48213"
}
```

> Kommt stattdessen `BucketAlreadyExists`? Dann hat schon jemand anderes auf der Welt diesen Namen. Probiere eine andere Zahl.

Schalte danach die **Versionierung** ein:

```bash
aws s3api put-bucket-versioning --bucket terraform-state-<dein-name>-<zahl> --versioning-configuration Status=Enabled
```

Dieser Befehl gibt nichts aus. Mit Versionierung hebt S3 bei jeder Änderung die vorherige Fassung auf. Geht beim State einmal etwas schief, kommst du an den alten Stand zurück.

### Schritt 2: Den Backend-Block einkommentieren

Öffne die `main.tf`. Entferne im `terraform`-Block die `#`-Zeichen vor dem Backend und trage **deinen** Bucket-Namen ein:

```hcl
  # Remote Backend: Der State liegt in einem S3-Bucket statt auf deinem Laptop.
  backend "s3" {
    bucket       = "terraform-state-anna-48213"
    key          = "terraform-kurs/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
```

> **Tipp:** Markiere die Zeilen in VS Code und drücke `Strg + #` (bzw. `Strg + /`) – das schaltet Kommentare ein und aus.

| Argument       | Bedeutung                                                                                                       |
| -------------- | --------------------------------------------------------------------------------------------------------------- |
| `bucket`       | Der Name deines Buckets                                                                                         |
| `key`          | Der **Pfad der Datei** im Bucket. So passen die States mehrerer Projekte in einen Bucket                        |
| `region`       | Die Region, in der der **Bucket** liegt                                                                         |
| `encrypt`      | Der State wird verschlüsselt gespeichert                                                                        |
| `use_lockfile` | **Sperre:** Während ein `apply` läuft, liegt eine Lock-Datei im Bucket. Ein zweites `apply` muss solange warten |

> **Warum steht hier kein `var.…`?** Im `backend`-Block sind **keine Variablen erlaubt**. Terraform muss den State finden, bevor es überhaupt Variablen auswerten kann. Der Bucket-Name steht deshalb fest im Code.

### Schritt 3: Den State umziehen

Das Backend hat sich geändert, also ist ein neues `init` nötig. Die Option `-migrate-state` sagt Terraform, dass der vorhandene State mit umziehen soll:

```bash
terraform init -migrate-state
```

Terraform fragt nach:

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  newly configured "s3" backend. No existing state was found in the newly
  configured "s3" backend. Do you want to copy this state to the new "s3"
  backend? Enter "yes" to copy and "no" to start with an empty state.

  Enter a value:
```

Tippe `yes`. **Das solltest du sehen:**

```
Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.

Terraform has been successfully initialized!
```

> **Achtung:** Antworte hier **nicht** mit `no`. Dann startet Terraform mit einem **leeren** State, „kennt“ deine neun Ressourcen nicht mehr und würde alles ein zweites Mal anlegen.

### Schritt 4: Prüfen, ob der Umzug geklappt hat

Liegt der State im Bucket?

```bash
aws s3 ls s3://terraform-state-<dein-name>-<zahl>/terraform-kurs/
```

**Das solltest du sehen** (Datum und Größe sind bei dir anders):

```
2026-10-12 10:42:17      21480 terraform.tfstate
```

Kennt Terraform seine Ressourcen noch?

```bash
terraform state list
terraform plan
```

**Das solltest du sehen:** die Liste mit allen neun Ressourcen (und der Data Source `data.aws_ami.ubuntu`) und danach

```
No changes. Your infrastructure matches the configuration.
```

**Genau das ist das Ziel:** An der Infrastruktur hat sich **nichts** geändert – nur der Ort, an dem Terraform sein Gedächtnis aufbewahrt.

Und lokal?

```bash
ls -l
```

Die Datei `terraform.tfstate` ist jetzt **leer** (0 Bytes), daneben liegt eine Sicherung `terraform.tfstate.backup`. Terraform liest ab sofort nur noch aus dem Bucket. Beide lokalen Dateien kannst du löschen:

```bash
rm terraform.tfstate terraform.tfstate.backup
```

Schau dir den Bucket auch in der Konsole an: Dienst **S3** → dein Bucket → Ordner `terraform-kurs/`.

> **Und im Team?** Jetzt könnte eine Kollegin dein Git-Repository klonen, `terraform init` ausführen und würde **denselben** State verwenden wie du. Versucht ihr gleichzeitig ein `apply`, bekommt die zweite Person die Meldung `Error acquiring the state lock` – und nichts geht kaputt.

---

## Zusatzaufgabe 1: nginx automatisch installieren (`user_data`)

In Kapitel 05 hast du dich per SSH verbunden und nginx von Hand installiert. Mit **`user_data`** gibst du der Instanz ein Skript mit, das beim **ersten Start** automatisch läuft.

### Schritt 1: Port 80 öffnen

Füge in der `main.tf` nach der SSH-Regel hinzu:

```hcl
# Eingehend: HTTP (Port 80) von überall
resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.server.id
  description       = "HTTP"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}
```

### Schritt 2: Das Startskript ergänzen

Ergänze im Block `aws_instance.server` (vor `tags`):

```hcl
  user_data_replace_on_change = true
  user_data                   = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    echo "<h1>Hallo von ${var.vorname} - gebaut mit Terraform!</h1>" > /var/www/html/index.html
  EOF
```

- `<<-EOF … EOF` ist ein **mehrzeiliger Text** (_Heredoc_). Alles zwischen den beiden `EOF` gehört dazu
- Das Skript läuft als `root`, deshalb ist kein `sudo` nötig
- `${var.vorname}` setzt Terraform ein, **bevor** das Skript zur Instanz geschickt wird
- `user_data_replace_on_change = true` – ändert sich das Skript, wird die Instanz **neu erstellt**. Sonst würde es nie ausgeführt, denn es läuft nur beim allerersten Start

### Schritt 3: Einen Output für die Adresse

In der `outputs.tf`:

```hcl
output "webseite" {
  description = "Adresse der Webseite"
  value       = "http://${aws_instance.server.public_ip}"
}
```

### Schritt 4: Plan lesen und anwenden

```bash
terraform plan
```

**Das solltest du sehen** (gekürzt):

```
  # aws_instance.server must be replaced
-/+ resource "aws_instance" "server" {
      ~ id                          = "i-0a1b2c3d4e5f67890" -> (known after apply)
      ~ public_ip                   = "3.91.45.67" -> (known after apply)
      + user_data                   = "…" # forces replacement
      ...
    }

Plan: 2 to add, 0 to change, 1 to destroy.
```

Da ist es: `-/+` und `must be replaced`. Die alte Instanz wird gelöscht, eine neue entsteht – zusammen mit der neuen Regel sind das **2 to add, 1 to destroy**.

```bash
terraform apply
```

Warte nach dem `apply` etwa **eine Minute** (das Skript braucht Zeit für die Installation) und öffne die Adresse aus dem Output `webseite` im Browser. Denke an `http://` – **ohne s**.

**Zum Knobeln:** Vergleiche die öffentliche IP vor und nach dem `apply`. Warum ist sie anders? Und was wäre mit Dateien passiert, die du per SSH auf der alten Instanz angelegt hattest?

<details>
<summary>Lösung</summary>

Die Instanz wurde nicht verändert, sondern **gelöscht und neu erstellt**. Eine neue Instanz bekommt eine neue öffentliche IP – und eine neue, leere Festplatte. Alles, was auf der alten Instanz lag, ist weg.

Deshalb gehört die Einrichtung eines Servers in den **Code** (`user_data`) und nicht in Handarbeit per SSH: Dann darf die Instanz jederzeit ersetzt werden.

</details>

## Zusatzaufgabe 2: SSH nur von deiner eigenen IP erlauben

`0.0.0.0/0` bei Port 22 bedeutet: Die ganze Welt darf versuchen, sich einzuloggen. Besser ist es, nur **deinen** Internetanschluss zuzulassen.

1. Finde deine öffentliche IP heraus (auf **deinem Laptop**, nicht auf dem Server):

   ```bash
   curl -s https://checkip.amazonaws.com
   ```

2. Lege in `variables.tf` eine neue Variable an:

   ```hcl
   variable "meine_ip" {
     description = "Deine öffentliche IP-Adresse – nur von dort ist SSH erlaubt"
     type        = string
   }
   ```

3. Trage den Wert in `terraform.tfvars` ein:

   ```hcl
   meine_ip = "203.0.113.25"
   ```

4. Ändere in der SSH-Regel (`aws_vpc_security_group_ingress_rule.ssh`) die Zeile `cidr_ipv4`:

   ```hcl
     cidr_ipv4         = "${var.meine_ip}/32"
   ```

   `/32` bedeutet: genau **diese eine** Adresse.

5. `terraform plan` – wird die Regel geändert (`~`) oder ersetzt (`-/+`)? Danach `terraform apply` und per SSH testen.

> Wechselst du das WLAN (z. B. von der Schule nach Hause), ändert sich deine IP. Dann bekommst du bei SSH `Connection timed out`. Die Lösung dauert jetzt zehn Sekunden: neuen Wert in `terraform.tfvars` eintragen, `terraform apply`.

## Zusatzaufgabe 3: Das Schlüsselpaar mit Terraform verwalten

Das Schlüsselpaar hast du in Aufgabe 2 von Hand angelegt. Es geht auch mit Terraform – **ohne** dass dein privater Schlüssel dabei deinen Laptop verlässt: Du erzeugst das Paar lokal und lädst nur den **öffentlichen** Teil hoch. Dasselbe Prinzip kennst du von GitHub aus Kapitel 03.

1. Ein neues Schlüsselpaar auf deinem Laptop erzeugen (die Frage nach der Passphrase mit `Enter` überspringen):

   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/terraform-kurs-lokal
   ```

   Es entstehen `terraform-kurs-lokal` (privat) und `terraform-kurs-lokal.pub` (öffentlich).

2. In der `main.tf` vor der Instanz ergänzen:

   ```hcl
   # Den öffentlichen Teil des Schlüssels zu AWS hochladen
   resource "aws_key_pair" "lokal" {
     key_name   = "${var.vorname}-terraform-key"
     public_key = file(pathexpand("~/.ssh/terraform-kurs-lokal.pub"))
   }
   ```

   `file(...)` liest den Inhalt einer Datei, `pathexpand(...)` ersetzt `~` durch dein Benutzerverzeichnis.

3. In `aws_instance.server` die Zeile `key_name` ändern:

   ```hcl
     key_name                    = aws_key_pair.lokal.key_name
   ```

4. In der `outputs.tf` im SSH-Befehl den Schlüssel anpassen: `-i ~/.ssh/terraform-kurs-lokal`

5. `terraform plan` lesen, dann `terraform apply`. Verbinde dich mit dem neuen Schlüssel.

**Zum Knobeln:** Was passiert laut Plan mit der Instanz – und warum? Und wieso wäre es **keine** gute Idee, stattdessen den **privaten** Schlüssel von Terraform erzeugen zu lassen?

<details>
<summary>Lösung</summary>

Die Instanz wird **ersetzt** (`-/+`, `key_name … # forces replacement`). Der Schlüssel wird nur beim ersten Start auf die Instanz kopiert und lässt sich bei AWS nachträglich nicht austauschen.

Würde Terraform den privaten Schlüssel erzeugen, stünde er **im Klartext im State** – und damit in deinem S3-Bucket, lesbar für alle, die Zugriff auf den Bucket haben. Geheimnisse gehören möglichst gar nicht in den State.

</details>

## Zusatzaufgabe 4: Was passiert, wenn jemand von Hand etwas ändert? (Drift)

1. Öffne in der AWS-Konsole deine Instanz → Reiter **Tags** → **Manage tags**
2. Ändere den Wert des Tags `Name` in `von-hand-geaendert` und füge einen zweiten Tag hinzu: Key `Abteilung`, Value `IT`. **Save**
3. Zurück im Terminal:

   ```bash
   terraform plan
   ```

**Zum Knobeln:** Was will Terraform tun? Was passiert mit dem Tag `Abteilung`, der in deinem Code gar nicht vorkommt? Führe danach `terraform apply` aus und prüfe es in der Konsole.

<details>
<summary>Lösung</summary>

Terraform bemerkt den Unterschied zwischen Code und Wirklichkeit – man nennt das **Drift**. Im Plan steht `~ update in-place`: Der Name wird zurück auf `<vorname>-server` gesetzt und der Tag `Abteilung` wird **entfernt** (`- "Abteilung" = "IT" -> null`).

Der Code ist die **eine Wahrheit**. Was von Hand geändert wurde, macht das nächste `apply` wieder rückgängig. Deshalb gilt in Projekten mit Terraform: **Änderungen nur noch über den Code**, nicht mehr über die Konsole.

</details>

---

## Befehlsübersicht

| Befehl                             | Bedeutung                                                       |
| ---------------------------------- | --------------------------------------------------------------- |
| `terraform init`                   | Projekt vorbereiten: Provider herunterladen, Backend einrichten |
| `terraform init -migrate-state`    | Wie `init`, zieht zusätzlich den State in ein neues Backend um  |
| `terraform fmt`                    | Code einheitlich formatieren                                    |
| `terraform validate`               | Code auf Syntaxfehler prüfen (ohne AWS)                         |
| `terraform plan`                   | Vorschau: Was würde sich ändern?                                |
| `terraform apply`                  | Änderungen durchführen (nach Bestätigung mit `yes`)             |
| `terraform destroy`                | **Alle** Ressourcen dieses Projekts löschen                     |
| `terraform output`                 | Die Outputs anzeigen                                            |
| `terraform output -raw <Name>`     | Einen einzelnen Output ohne Anführungszeichen anzeigen          |
| `terraform state list`             | Alle Ressourcen im State auflisten                              |
| `terraform state show <Ressource>` | Details einer Ressource aus dem State anzeigen                  |
| `terraform version`                | Version von Terraform und den Providern anzeigen                |
| `aws sts get-caller-identity`      | Prüfen, mit welchem AWS-Benutzer du angemeldet bist             |
| `aws configure`                    | AWS-Zugangsdaten hinterlegen                                    |

## Aufräumen

Eine laufende Instanz kostet Geld. Bei Terraform ist Aufräumen **ein Befehl** – und du kannst dir sicher sein, dass nichts vergessen wird.

### Schritt 1: Die Infrastruktur löschen

```bash
cd ~/terraform-kurs
terraform destroy
```

Terraform zeigt einen Plan, in dem vor **jeder** Ressource ein `-` steht, und fragt nach. Lies die letzte Zeile:

```
Plan: 0 to add, 0 to change, 9 to destroy.
```

Mit `yes` bestätigen. **Das solltest du am Ende sehen** (bei dir können es durch die Zusatzaufgaben mehr sein):

```
Destroy complete! Resources: 9 destroyed.
```

Auch hier kümmert sich Terraform um die Reihenfolge – diesmal rückwärts: erst die Instanz, ganz zum Schluss das VPC. Prüfe in der Konsole: Die Instanz steht auf **Terminated**, das VPC ist verschwunden.

> **Das Schöne daran:** Dein Code ist noch da. Ein `terraform apply`, und in einer Minute steht alles wieder – genau so wie vorher.

### Schritt 2: Was Terraform **nicht** löscht

Terraform löscht nur, was es selbst angelegt hat. Übrig bleiben die beiden Dinge, die du **von Hand** erstellt hast:

| Was                   | Kostet es etwas?                   | So löschst du es                                                                                          |
| --------------------- | ---------------------------------- | --------------------------------------------------------------------------------------------------------- |
| **Schlüsselpaar**     | Nein                               | **EC2** → **Key Pairs** → auswählen → **Actions** → **Delete**. Danach `rm ~/.ssh/terraform-kurs-key.pem` |
| **S3-Bucket** (State) | Praktisch nichts (wenige Kilobyte) | **S3** → Bucket auswählen → **Empty** → danach **Delete**                                                 |

> Den Bucket löschst du **erst nach** `terraform destroy`. Löschst du ihn vorher, ist der State weg – und du musst alle Ressourcen einzeln in der Konsole zusammensuchen.

Brauchst du Schlüsselpaar und Bucket in der nächsten Stunde wieder, lass sie einfach stehen.

## Fehlerbehebung

| Fehlermeldung / Problem                                                           | Mögliche Ursache und Lösung                                                                                                                                     |
| --------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `No valid credential sources found`                                               | Keine Zugangsdaten hinterlegt → `aws configure` ausführen und mit `aws sts get-caller-identity` prüfen                                                          |
| `InvalidClientTokenId` oder `SignatureDoesNotMatch`                               | Access Key falsch abgetippt oder gelöscht → `aws configure` erneut ausführen                                                                                    |
| `UnauthorizedOperation` / `AccessDenied`                                          | Deinem AWS-Benutzer fehlen Rechte → an die Kursleitung wenden                                                                                                   |
| `Inconsistent dependency lock file` oder `Required plugins are not installed`     | `terraform init` wurde in diesem Ordner noch nicht ausgeführt                                                                                                   |
| `No configuration files`                                                          | Du bist im falschen Ordner → `pwd` und `cd ~/terraform-kurs`                                                                                                    |
| `Unsupported argument` / `Missing required argument`                              | Tippfehler in einem Argument. Terraform nennt Datei und Zeile – dort nachsehen                                                                                  |
| `Reference to undeclared resource`                                                | Tippfehler in einem Verweis, z. B. `aws_vpc.mian.id`. Der Name muss exakt zum `resource`-Block passen                                                           |
| `InvalidKeyPair.NotFound`                                                         | Das Schlüsselpaar heißt anders oder liegt in einer **anderen Region** → **EC2** → **Key Pairs** in `us-east-1` prüfen                                           |
| `VpcLimitExceeded`                                                                | Pro Region sind standardmäßig nur **5 VPCs** erlaubt → nicht mehr benötigte VPCs (z. B. aus Kapitel 05) in der Konsole löschen                                  |
| `InvalidParameterValue … Character sets beyond ASCII are not supported`           | Umlaut oder ß in der `description` einer Security Group oder Regel → durch `ue`, `ae`, `oe`, `ss` ersetzen                                                      |
| `Connection timed out` bei SSH                                                    | Instanz fährt noch hoch (30 Sekunden warten), die SSH-Regel fehlt oder (Zusatzaufgabe 2) deine IP hat sich geändert                                             |
| `Permission denied (publickey)`                                                   | Falscher Schlüssel bei `-i` oder falscher Benutzername (muss `ubuntu` sein)                                                                                     |
| `WARNING: UNPROTECTED PRIVATE KEY FILE!`                                          | Dateirechte zu offen → `chmod 400 ~/.ssh/terraform-kurs-key.pem`                                                                                                |
| `Backend configuration changed`                                                   | Der `backend`-Block wurde geändert → `terraform init -migrate-state`                                                                                            |
| `BucketAlreadyExists` beim Anlegen des Buckets                                    | Der Name ist weltweit schon vergeben → andere Zahl anhängen                                                                                                     |
| `S3 bucket "…" does not exist` bei `terraform init`                               | Bucket-Name im `backend`-Block stimmt nicht mit dem angelegten Bucket überein → mit `aws s3 ls` vergleichen                                                     |
| `Error acquiring the state lock`                                                  | Ein anderes `apply` läuft gerade – oder ein früheres wurde hart abgebrochen. Im zweiten Fall: `terraform force-unlock <Lock-ID>` (die ID steht in der Meldung)  |
| `terraform plan` will plötzlich die Instanz ersetzen (`ami … forces replacement`) | Canonical hat eine neuere Ubuntu-AMI veröffentlicht, die Data Source findet jetzt diese. Für den Kurs unkritisch – in echten Projekten legt man die AMI-ID fest |
| `terraform plan` fragt nach `var.vorname`                                         | Die Datei heißt nicht genau `terraform.tfvars` oder liegt nicht im Projektordner                                                                                |
| `apply` wurde mit `Strg + C` abgebrochen                                          | Kein Problem: einfach `terraform apply` erneut ausführen. Terraform macht dort weiter, wo es aufgehört hat                                                      |

## Kontrollfragen

- Was bedeutet **Infrastructure as Code**? Nenne zwei Vorteile gegenüber dem Klicken in der Konsole.
- Was heißt **deklarativ** – und wo ist dir dieses Prinzip schon einmal begegnet?
- Was ist der Unterschied zwischen einer **Resource** und einer **Data Source**?
- Was macht `terraform init`, und wann musst du es erneut ausführen?
- Was ist der Unterschied zwischen `terraform plan` und `terraform apply`?
- Was bedeuten die Zeichen `+`, `~`, `-` und `-/+` in einem Plan?
- Woher weiß Terraform, dass das VPC **vor** dem Subnetz angelegt werden muss?
- Welche fünf Ressourcen braucht ein **öffentliches** Subnetz?
- Wofür braucht Terraform den **State**? Was würde passieren, wenn du die Datei löschst?
- Warum gehören `terraform.tfstate` und `.terraform/` **nicht** in Git – `.terraform.lock.hcl` aber schon?
- Welche Vorteile hat ein **Remote Backend** gegenüber dem lokalen State?
- Warum hast du Schlüsselpaar und S3-Bucket **von Hand** angelegt und nicht mit Terraform?
- Warum stehen deine AWS-Zugangsdaten **nicht** in der `main.tf`?
- Was ist der Unterschied zwischen `variables.tf` und `terraform.tfvars`?
- Jemand ändert in der Konsole von Hand einen Tag an deiner Instanz. Was passiert beim nächsten `terraform apply`?
