# CI/CD: Automatisch testen und ausliefern

In den letzten Kapiteln hast du vieles **von Hand im Terminal** ausgeführt: `docker build`, `kubectl apply`, `terraform plan` und `terraform apply`. Das klappt – solange **du** daran denkst, **du** die richtigen Befehle in der richtigen Reihenfolge tippst und **dein** Laptop richtig eingerichtet ist.

Was aber, wenn fünf Leute am selben Projekt arbeiten? Wer prüft, ob eine Änderung den Code kaputt macht? Wer spielt sie auf den Server – und mit welchen Zugangsdaten? Genau hier setzt **CI/CD** an: Bei jedem `git push` startet automatisch eine **Pipeline**, die deinen Code prüft, testet und – wenn alles grün ist – ausliefert.

Dieses Kapitel hat zwei Teile:

| Teil                                               | Inhalt                                                                                                                             |
| -------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| **Teil 1** (diese Datei)                           | Wiederholung: Grundbegriffe von CI/CD und GitHub Actions, fünf Übungen vom „Hallo Welt“-Workflow bis zum Docker-Build              |
| **Teil 2** → [TERRAFORM-PIPELINE.md](./TERRAFORM-PIPELINE.md) | Umgebungsvariablen und Secrets, Pull Requests, Branch-Schutz – und das **Terraform-Deployment aus Kapitel 08 vollständig automatisieren** |

## Grundbegriffe

### Was ist CI/CD?

**CI/CD** steht für drei eng verwandte Ideen:

| Abkürzung | Ausgeschrieben              | Bedeutung                                                                                                                                  |
| --------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| **CI**    | **Continuous Integration**  | Jede Änderung wird **sofort** in den gemeinsamen Code integriert und **automatisch geprüft** (bauen, testen, Formatierung, Sicherheit …)   |
| **CD**    | **Continuous Delivery**     | Nach erfolgreicher Prüfung liegt automatisch eine **auslieferbare Version** bereit. Das Ausrollen in Produktion löst ein **Mensch** per Klick aus |
| **CD**    | **Continuous Deployment**   | Wie Delivery – nur ohne den Klick: Jede grüne Änderung geht **vollautomatisch** in Produktion                                              |

> **Vergleich:** Eine **Autowerkstatt mit Prüfstraße**. CI ist die Prüfstraße, durch die jedes reparierte Auto fährt (Bremsen, Licht, Abgase). Continuous Delivery heißt: Das geprüfte Auto steht abholbereit auf dem Hof, der Kunde holt es, wann er will. Continuous Deployment heißt: Das Auto wird nach bestandener Prüfung **sofort** vor die Haustür des Kunden gefahren.

Der Unterschied zwischen Delivery und Deployment ist also nur **ein einziger Schritt**: die **manuelle Freigabe**. Beides wirst du in Teil 2 mit Terraform ausprobieren.

### Warum das Ganze?

| Ohne CI/CD                                                  | Mit CI/CD                                                         |
| ----------------------------------------------------------- | ----------------------------------------------------------------- |
| „Bei mir läuft’s aber!“ – jeder Laptop ist anders           | Die Pipeline läuft **immer in derselben, frischen Umgebung**      |
| Tests werden vergessen, wenn es eilig ist                   | Tests laufen **bei jedem Push**, niemand kann sie überspringen    |
| Fehler fallen erst in Produktion auf                        | Fehler fallen **Minuten** nach dem Push auf – im Pull Request     |
| Deployment = eine Person mit Zugangsdaten auf ihrem Laptop  | Deployment = ein **nachvollziehbarer** Lauf mit Log und Historie  |
| Zugangsdaten liegen auf vielen Laptops                      | Zugangsdaten liegen **an einer Stelle** (als Secret in GitHub)    |

### Die Pipeline

Eine **Pipeline** ist die Abfolge von Schritten, die bei einer Änderung automatisch abläuft. Klassisch sieht das so aus:

```
  git push
     │
     ▼
 ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌───────────┐    ┌───────────┐
 │  Build  │───▶│  Test   │───▶│ Package │───▶│  Deploy   │───▶│  Deploy   │
 │         │    │         │    │         │    │  Staging  │    │  Prod     │
 └─────────┘    └─────────┘    └─────────┘    └───────────┘    └───────────┘
  Code bauen     Unit-Tests,    Docker-Image    Testumgebung    Echte Kunden
                 Linting        erstellen
 └──────────────── CI ────────────────────┘   └──────────── CD ────────────┘
```

Schlägt **ein** Schritt fehl (z. B. ein Test), bricht die Pipeline ab – die kaputte Änderung kommt **nie** in Produktion.

### Was ist GitHub Actions?

**GitHub Actions** ist das CI/CD-System, das direkt in GitHub eingebaut ist. Du legst eine **YAML-Datei** im Ordner `.github/workflows/` deines Repositories ab – und GitHub führt sie bei bestimmten Ereignissen automatisch aus. Andere bekannte Werkzeuge sind GitLab CI, Jenkins, Azure DevOps und CircleCI. Die Begriffe unterscheiden sich, das Prinzip ist überall gleich.

### Die wichtigsten Begriffe in GitHub Actions

| Begriff      | Bedeutung                                                                                                   | Vergleich                                  |
| ------------ | ----------------------------------------------------------------------------------------------------------- | ------------------------------------------ |
| **Workflow** | Eine YAML-Datei in `.github/workflows/`. Beschreibt eine komplette Automatisierung                          | Das Rezept                                 |
| **Event**    | Das Ereignis, das den Workflow startet (`push`, `pull_request`, Knopfdruck, Uhrzeit …). Steht unter `on:`   | Der Auslöser: „Wenn Gäste kommen …“        |
| **Job**      | Eine Gruppe von Schritten, die **auf demselben Rechner** laufen. Mehrere Jobs laufen standardmäßig **parallel** | Ein Koch an seiner Station                 |
| **Step**     | Ein einzelner Schritt in einem Job: entweder ein Shell-Befehl (`run:`) oder eine fertige Action (`uses:`)   | Ein Arbeitsschritt im Rezept               |
| **Action**   | Ein wiederverwendbarer, fertiger Baustein, z. B. `actions/checkout` (Code holen)                            | Ein Küchengerät, das man nicht selbst baut |
| **Runner**   | Die (virtuelle) Maschine, auf der ein Job läuft. Bei `ubuntu-latest` eine **frische** Ubuntu-VM von GitHub  | Die Küche                                  |
| **Run**      | Eine einzelne Ausführung eines Workflows, mit Log – zu finden im Reiter **Actions**                         | Ein gekochtes Gericht                      |

> **Ganz wichtig:** Ein GitHub-Runner ist bei **jedem** Lauf eine **brandneue, leere** Maschine. Nach dem Lauf wird sie gelöscht. Dein Code ist dort nicht automatisch vorhanden (dafür gibt es `actions/checkout`) – und alles, was du dort speicherst, ist danach weg. Das wird in Teil 2 beim Terraform-State noch sehr wichtig!

### So sieht ein Workflow aus

Diesen Workflow kennst du schon aus dem Kurs-Repository: [.github/workflows/hello-from-main.yml](../.github/workflows/hello-from-main.yml)

```yaml
name: Hello on main            # Anzeigename im Reiter "Actions"

on:                            # WANN läuft der Workflow?
  push:
    branches:
      - main                   # ... bei jedem Push auf main

jobs:                          # WAS soll passieren?
  hello:                       # Job-ID (frei wählbar)
    runs-on: ubuntu-latest     # WO? Auf einer frischen Ubuntu-VM
    steps:
      - name: Say hello        # Anzeigename des Schritts
        run: |                 # Shell-Befehle; "|" = mehrzeilig
          echo "Hallo, ${{ github.actor }}!"
          echo "Commit: ${{ github.sha }}"
          echo "Branch: ${{ github.ref_name }}"
```

| Teil                 | Bedeutung                                                                                                          |
| -------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `on:`                | Die **Events**. Hier: nur Pushes auf den Branch `main`                                                             |
| `jobs:`              | Die Liste der Jobs. `hello` ist die **ID**, die du selbst vergibst                                                 |
| `runs-on:`           | Auf welchem **Runner** der Job läuft                                                                               |
| `steps:`             | Die Schritte, die **nacheinander** ausgeführt werden                                                               |
| `run:`               | Ein Shell-Befehl, genau wie in deinem Terminal                                                                     |
| `${{ … }}`           | Ein **Ausdruck**. GitHub ersetzt ihn vor dem Ausführen durch einen Wert. `github.actor` = wer gepusht hat          |

> **YAML-Falle Nr. 1: Einrückung.** YAML erkennt die Struktur **nur** an den Leerzeichen am Zeilenanfang. Nimm immer **2 Leerzeichen**, **niemals Tabs**. Ein Leerzeichen zu viel oder zu wenig – und GitHub meldet `Invalid workflow file`. Die VS-Code-Erweiterung **GitHub Actions** (von GitHub) markiert solche Fehler sofort.

### Der Weg vom Push zum Ergebnis

```
   Dein Laptop                     GitHub                                Runner (frische VM)
 ┌──────────────┐   git push   ┌──────────────────────┐   startet    ┌──────────────────────────┐
 │ Code ändern  │─────────────▶│ Repository           │─────────────▶│ 1. Code auschecken       │
 │ git commit   │              │ .github/workflows/   │              │ 2. Befehle ausführen     │
 └──────────────┘              │   *.yml              │◀─────────────│ 3. Ergebnis melden       │
        ▲                      └──────────┬───────────┘   ✅ / ❌    └──────────────────────────┘
        │                                 │                            danach gelöscht
        └──────── Ergebnis im Browser ────┘
                  (Reiter "Actions", Häkchen am Commit)
```

## Voraussetzungen

- Ein **GitHub-Account** und eine funktionierende **SSH-Verbindung** zu GitHub (siehe Kapitel 03)
- **Git** und **VS Code** (siehe Kapitel 02) – empfehlenswert: die VS-Code-Erweiterung **GitHub Actions**
- Für Aufgabe 5: Du weißt, was ein **Dockerfile** ist (siehe Kapitel 06)

> **Kosten:** GitHub Actions ist für **öffentliche** Repositories kostenlos. Für private Repositories gibt es im kostenlosen Plan 2.000 Minuten pro Monat – für diesen Kurs mehr als genug.

## Überblick: Was machst du in Teil 1?

| Aufgabe | Inhalt                                                  | Ergebnis                                                     |
| ------- | ------------------------------------------------------- | ------------------------------------------------------------ |
| **1**   | Übungs-Repository und erster Workflow                   | Ein grüner Lauf im Reiter **Actions**                        |
| **2**   | Events: `push`, `pull_request`, Knopfdruck              | Du weißt, **wann** welcher Workflow startet                  |
| **3**   | Mehrere Jobs: parallel und nacheinander (`needs`)       | Eine Pipeline **Build → Test → Deploy**                      |
| **4**   | Code auschecken, testen – und die Pipeline rot machen   | Ein ❌, der eine kaputte Änderung aufhält                     |
| **5**   | Ein Docker-Image in der Pipeline bauen und testen       | Die Webseite aus Kapitel 06 wird automatisch geprüft         |

Die fertigen Dateien findest du zum Vergleichen in [beispiel-uebung](./beispiel-uebung/). Danach geht es weiter mit **Teil 2** → [TERRAFORM-PIPELINE.md](./TERRAFORM-PIPELINE.md).

---

## Aufgabe 1: Übungs-Repository und erster Workflow

### Schritt 1: Repository anlegen

1. Auf [github.com](https://github.com) oben rechts **+** → **New repository**
2. Name: `ci-cd-uebung`, Sichtbarkeit: **Public**, Häkchen bei **Add a README file**
3. **Create repository**
4. Die SSH-Adresse kopieren (**Code** → **SSH**) und das Repository klonen:

```bash
cd ~
git clone git@github.com:<dein-github-name>/ci-cd-uebung.git
cd ci-cd-uebung
code .
```

### Schritt 2: Den Workflow anlegen

GitHub sucht Workflows **ausschließlich** im Ordner `.github/workflows/` (mit Punkt am Anfang!). Lege die Datei `.github/workflows/hallo.yml` an:

```yaml
name: Hallo Pipeline

on:
  push:
    branches:
      - main

jobs:
  hallo:
    runs-on: ubuntu-latest
    steps:
      - name: Begrüßung
        run: echo "Hallo ${{ github.actor }}, die Pipeline läuft!"

      - name: Wo bin ich eigentlich?
        run: |
          echo "Betriebssystem:"
          cat /etc/os-release | head -2
          echo "Benutzer: $(whoami)"
          echo "Ordner:   $(pwd)"
          echo "Inhalt:"
          ls -la
```

### Schritt 3: Pushen und zuschauen

```bash
git add .
git commit -m "Ersten Workflow anlegen"
git push
```

1. Im Browser dein Repository öffnen → Reiter **Actions**
2. Dort erscheint ein Lauf mit dem Namen deines Commits. Ein gelber Kreis 🟡 heißt: läuft gerade
3. Auf den Lauf klicken → auf den Job **hallo** klicken → die Schritte aufklappen

**Das solltest du sehen:** einen grünen Haken ✅ und im Schritt **Wo bin ich eigentlich?** etwa

```
Betriebssystem:
PRETTY_NAME="Ubuntu 24.04.3 LTS"
NAME="Ubuntu"
Benutzer: runner
Ordner:   /home/runner/work/ci-cd-uebung/ci-cd-uebung
Inhalt:
total 8
drwxr-xr-x 2 runner docker 4096 Oct 26 10:12 .
drwxr-xr-x 3 runner docker 4096 Oct 26 10:12 ..
```

> **Fällt dir etwas auf?** Der Ordner ist **leer** – obwohl dein Repository eine `README.md` und den Workflow enthält. Der Runner ist eine frische VM, dein Code liegt dort **nicht** automatisch. Das änderst du in Aufgabe 4.

Schau dir auch die Startseite deines Repositories an: Neben dem letzten Commit steht jetzt ein ✅. Auf diese Weise sieht jeder im Team sofort, ob der aktuelle Stand in Ordnung ist.

---

## Aufgabe 2: Events – wann startet ein Workflow?

Bisher startet der Workflow nur bei einem Push auf `main`. In der Praxis brauchst du verschiedene Auslöser:

| Event               | Wann?                                                  | Typischer Einsatz                                     |
| ------------------- | ------------------------------------------------------ | ----------------------------------------------------- |
| `push`              | Commits werden auf einen Branch gepusht                | Tests auf jedem Branch, Deployment nach Push auf main |
| `pull_request`      | Ein Pull Request wird geöffnet oder aktualisiert       | Änderungen **vor** dem Mergen prüfen                  |
| `workflow_dispatch` | Jemand klickt im Reiter **Actions** auf **Run workflow** | Manuelle Aufgaben, z. B. Aufräumen                    |
| `schedule`          | Zu festen Zeiten (Cron-Syntax)                         | Nächtliche Prüfungen                                  |

### Schritt 1: Mehrere Events eintragen

Lege eine zweite Datei `.github/workflows/events.yml` an:

```yaml
name: Events verstehen

on:
  push:
    branches:
      - "**"            # alle Branches
  pull_request:
    branches:
      - main            # PRs, die nach main gemergt werden sollen
  workflow_dispatch:    # Knopf "Run workflow"

jobs:
  info:
    runs-on: ubuntu-latest
    steps:
      - name: Infos zum Auslöser
        run: |
          echo "Event:      ${{ github.event_name }}"
          echo "Branch:     ${{ github.ref_name }}"
          echo "Ausgelöst:  ${{ github.actor }}"
          echo "Commit:     ${{ github.sha }}"
```

Committen und pushen. Im Reiter **Actions** siehst du jetzt **zwei** Läufe: `Hallo Pipeline` und `Events verstehen` – denn beide reagieren auf einen Push auf `main`.

### Schritt 2: Per Knopfdruck starten

1. Reiter **Actions** → links **Events verstehen** auswählen
2. Rechts **Run workflow** → **Run workflow**
3. Im Log steht jetzt `Event: workflow_dispatch`

> Der Knopf **Run workflow** erscheint nur, wenn die Workflow-Datei mit `workflow_dispatch` bereits auf dem **Standard-Branch** (`main`) liegt.

### Schritt 3: Einen Branch und einen Pull Request

```bash
git switch -c feature/test-events
echo "Eine Zeile" >> README.md
git commit -am "Teständerung auf Branch"
git push -u origin feature/test-events
```

Im Reiter **Actions** startet jetzt **nur** `Events verstehen` (Event `push`, Branch `feature/test-events`). `Hallo Pipeline` reagiert nur auf `main`.

Öffne jetzt auf GitHub einen **Pull Request** von `feature/test-events` nach `main` (GitHub zeigt dir oben einen gelben Hinweis mit **Compare & pull request**). Im PR siehst du unten den Bereich **Checks** – dort läuft `Events verstehen` erneut, diesmal mit `Event: pull_request`.

> Den PR noch **nicht** mergen – du brauchst ihn in Aufgabe 4 nicht, kannst ihn aber offen lassen oder schließen.

---

## Aufgabe 3: Mehrere Jobs – parallel und nacheinander

Ein Workflow kann mehrere Jobs haben. Ohne weitere Angabe laufen sie **gleichzeitig** auf **verschiedenen** Runnern. Mit `needs:` legst du eine **Reihenfolge** fest.

### Schritt 1: Eine kleine Pipeline

Wechsle zurück auf `main` und lege `.github/workflows/pipeline.yml` an:

```bash
git switch main
```

```yaml
name: Build-Test-Deploy

on:
  push:
    branches:
      - main
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - run: echo "🔨 Baue die Anwendung ..."

  lint:
    runs-on: ubuntu-latest
    steps:
      - run: echo "🧹 Prüfe die Formatierung ..."

  test:
    runs-on: ubuntu-latest
    needs: build                 # wartet auf build
    steps:
      - run: echo "🧪 Führe die Tests aus ..."

  deploy:
    runs-on: ubuntu-latest
    needs: [lint, test]          # wartet auf lint UND test
    steps:
      - run: echo "🚀 Rolle die Anwendung aus ..."
```

### Schritt 2: Den Graphen ansehen

Pushen, dann im Reiter **Actions** den Lauf öffnen. GitHub zeichnet die Jobs als **Graph**:

```
  ┌───────┐      ┌──────┐
  │ build │─────▶│ test │──┐
  └───────┘      └──────┘  │     ┌────────┐
                           ├────▶│ deploy │
  ┌───────┐                │     └────────┘
  │ lint  │────────────────┘
  └───────┘
```

`build` und `lint` starten **gleichzeitig**. `test` wartet auf `build`, `deploy` wartet auf **beide**. Schlägt `test` fehl, wird `deploy` **übersprungen** – genau das willst du: Ungetesteter Code wird nicht ausgerollt.

> **Wichtig:** Jeder Job läuft auf einem **eigenen** Runner. Eine Datei, die `build` erzeugt, ist im Job `test` **nicht** vorhanden. Wer Dateien zwischen Jobs weitergeben will, braucht **Artifacts** (`actions/upload-artifact` / `actions/download-artifact`) – das kommt in Teil 2 vor.

---

## Aufgabe 4: Code auschecken, testen – und die Pipeline rot machen

Jetzt wird es ernst: Die Pipeline soll **deinen Code** prüfen. Dafür muss der Code zuerst auf den Runner – das erledigt die fertige Action `actions/checkout`.

### Schritt 1: Eine Webseite und ein Test

Lege im Repository die Datei `index.html` an (wie in Kapitel 06):

```html
<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <title>Meine CI/CD-Webseite</title>
  </head>
  <body>
    <h1>Hallo aus der Pipeline! 🚀</h1>
    <p>Version: 1.0</p>
  </body>
</html>
```

Und daneben ein kleines Test-Skript `test.sh`:

```bash
#!/usr/bin/env bash
# Bricht beim ersten Fehler ab
set -e

echo "Prüfe, ob index.html existiert ..."
test -f index.html

echo "Prüfe, ob es einen <title> gibt ..."
grep -q "<title>" index.html

echo "Prüfe, ob es eine <h1>-Überschrift gibt ..."
grep -q "<h1>" index.html

echo "✅ Alle Tests bestanden"
```

Lokal ausprobieren:

```bash
chmod +x test.sh
./test.sh
echo "Exit-Code: $?"
```

**Das solltest du sehen:**

```
Prüfe, ob index.html existiert ...
Prüfe, ob es einen <title> gibt ...
Prüfe, ob es eine <h1>-Überschrift gibt ...
✅ Alle Tests bestanden
Exit-Code: 0
```

> **Der Exit-Code ist die Sprache der Pipeline.** Jedes Programm meldet beim Beenden eine Zahl: `0` heißt „alles gut“, alles andere heißt „Fehler“. GitHub Actions schaut **nur** auf diese Zahl: `0` → ✅, sonst → ❌ und der Job bricht ab. `grep -q` liefert `1`, wenn es nichts findet – und `set -e` sorgt dafür, dass das Skript dann sofort mit diesem Fehler endet.

### Schritt 2: Der Test-Workflow

Lege `.github/workflows/test.yml` an:

```yaml
name: Tests

on:
  push:
    branches:
      - "**"
  pull_request:
    branches:
      - main

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Inhalt anzeigen
        run: ls -la

      - name: Tests ausführen
        run: ./test.sh
```

| Zeile                          | Bedeutung                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------------------------- |
| `uses: actions/checkout@v5`    | Eine fertige **Action** aus dem GitHub-Marketplace: klont dein Repository auf den Runner        |
| `@v5`                          | Die **Version** der Action. Immer angeben – sonst kann sich das Verhalten ungefragt ändern      |
| `run: ./test.sh`               | Führt **dasselbe** Skript aus wie auf deinem Laptop                                             |

Committen und pushen. Im Schritt **Inhalt anzeigen** liegen jetzt deine Dateien auf dem Runner, und **Tests ausführen** ist grün.

> **Prinzip:** Eine Pipeline macht nichts Magisches. Sie führt **dieselben Befehle** aus, die du auch lokal ausführen würdest – nur automatisch, jedes Mal, in einer sauberen Umgebung.

### Schritt 3: Die Pipeline absichtlich kaputt machen

Lege einen neuen Branch an und „vergiss“ die Überschrift:

```bash
git switch -c feature/kaputt
```

Ändere in `index.html` die Zeile `<h1>Hallo aus der Pipeline! 🚀</h1>` in `<p>Hallo aus der Pipeline! 🚀</p>`.

```bash
git commit -am "Überschrift entfernt"
git push -u origin feature/kaputt
```

Öffne einen **Pull Request** nach `main`.

**Das solltest du sehen:** Im PR steht bei den Checks ein rotes ❌ `Tests / test (pull_request) – Failing`. Klickst du auf **Details**, findest du im Log:

```
Prüfe, ob es eine <h1>-Überschrift gibt ...
Error: Process completed with exit code 1.
```

Genau dafür ist CI da: Die Reviewerin sieht **vor** dem Mergen, dass die Änderung etwas kaputt macht.

### Schritt 4: Reparieren

Stelle die `<h1>`-Zeile wieder her, committe und pushe auf **denselben** Branch:

```bash
git commit -am "Überschrift wiederhergestellt"
git push
```

Der PR aktualisiert sich automatisch, die Tests laufen erneut – und werden grün ✅. Jetzt darfst du den PR mergen.

> **Aber:** Im Moment **könntest** du den PR auch mit rotem ❌ mergen – GitHub warnt nur. Wie man das **verbietet**, lernst du in Teil 2 mit dem **Branch-Schutz**.

---

## Aufgabe 5: Ein Docker-Image in der Pipeline bauen und testen

Auf den GitHub-Runnern ist **Docker bereits installiert**. Du kannst also die Webseite aus Kapitel 06 in der Pipeline als Image bauen, als Container starten und prüfen, ob sie antwortet.

### Schritt 1: Das Dockerfile

Lege im Repository ein `Dockerfile` an:

```dockerfile
# Basis-Image: ein sehr kleines nginx auf Alpine Linux
FROM nginx:alpine

# Unsere Webseite in den Ordner kopieren, aus dem nginx ausliefert
COPY index.html /usr/share/nginx/html/index.html

# Dokumentation: Der Container lauscht auf Port 80
EXPOSE 80
```

### Schritt 2: Den Docker-Job ergänzen

Erweitere `.github/workflows/test.yml` um einen **zweiten Job**, der erst nach den Tests läuft:

```yaml
  docker:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - name: Code auschecken
        uses: actions/checkout@v5

      - name: Image bauen
        run: docker build -t meine-webseite:${{ github.sha }} .

      - name: Container starten
        run: docker run -d --name web -p 8080:80 meine-webseite:${{ github.sha }}

      - name: Antwortet die Webseite?
        run: |
          sleep 2
          curl --fail --silent http://localhost:8080 | grep "Hallo aus der Pipeline"

      - name: Aufräumen
        if: always()
        run: docker rm -f web
```

| Zeile                    | Bedeutung                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------- |
| `needs: test`            | Docker wird nur gebaut, wenn die Tests grün sind                                                              |
| `:${{ github.sha }}`     | Das Image bekommt die **Commit-ID** als Tag. So weiß man später genau, aus welchem Code ein Image stammt      |
| `curl --fail`            | Liefert einen Exit-Code ≠ 0, wenn der Server einen Fehler (z. B. 404) zurückgibt                              |
| `if: always()`           | Dieser Schritt läuft **auch dann**, wenn ein vorheriger Schritt fehlgeschlagen ist                            |

Committen und pushen. **Das solltest du sehen:** zwei Jobs, `test` → `docker`, beide grün. Im Schritt **Antwortet die Webseite?** steht die Zeile mit deiner Überschrift.

> **Wie ginge es weiter?** In einem echten Projekt würde die Pipeline das Image jetzt in eine **Registry** hochladen (z. B. Docker Hub oder die GitHub Container Registry `ghcr.io`) und danach im Kubernetes-Cluster aus Kapitel 07 ausrollen. Das ist das „CD“ zum „CI“. Wir machen das CD in Teil 2 – allerdings mit **Terraform** und echter Infrastruktur in AWS.

---

## Kontrollfragen

- Wofür stehen **CI** und **CD**? Was ist der Unterschied zwischen Continuous **Delivery** und Continuous **Deployment**?
- Erkläre die Begriffe **Workflow**, **Event**, **Job**, **Step**, **Action** und **Runner**.
- In welchem Ordner müssen Workflow-Dateien liegen?
- Warum ist der Arbeitsordner auf dem Runner leer, wenn du `actions/checkout` weglässt?
- Woran erkennt GitHub Actions, ob ein Schritt erfolgreich war?
- Zwei Jobs stehen ohne `needs` im selben Workflow. In welcher Reihenfolge laufen sie?
- Job A erzeugt eine Datei. Kann Job B sie lesen? Warum (nicht)?
- Wozu dient `workflow_dispatch`?
- Ein Workflow hat `on: push: branches: [main]`. Läuft er, wenn du auf `feature/xyz` pushst?
- Warum sollte man bei `uses:` immer eine Version (`@v5`) angeben?
- Warum ist es sinnvoll, ein Docker-Image mit der Commit-ID zu taggen?

---

➡️ **Weiter mit Teil 2:** [TERRAFORM-PIPELINE.md](./TERRAFORM-PIPELINE.md) – Umgebungsvariablen, Secrets, Pull Requests und das automatische Terraform-Deployment.
