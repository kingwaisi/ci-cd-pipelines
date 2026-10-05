# k3d unter Windows

Das [Haupt-Readme](./Readme.md) geht davon aus, dass du im **Ubuntu-Terminal der WSL** arbeitest. Diese Seite beschreibt, was unter Windows zu beachten ist – und wie du k3d auch **ohne WSL** direkt in der **PowerShell** verwendest.

## Welcher Weg passt zu dir?

|                 | **Weg A: in der WSL** (empfohlen)                              | **Weg B: PowerShell + Docker Desktop**                     |
| --------------- | -------------------------------------------------------------- | ---------------------------------------------------------- |
| Docker          | Docker Engine in Ubuntu (Kapitel 06)                           | **Docker Desktop** für Windows                             |
| Terminal        | Ubuntu                                                         | PowerShell                                                 |
| Anleitung       | [Haupt-Readme](./Readme.md) **unverändert**                    | Diese Seite, dann Haupt-Readme ab Aufgabe 2                |
| Für wen?        | Alle, die Kapitel 06 gemacht haben                             | Wer bereits mit Docker Desktop arbeitet                    |

> **Nicht mischen:** Docker Engine in der WSL und Docker Desktop sind **zwei getrennte Docker-Installationen** mit getrennten Images und Containern. Entscheide dich für **einen** Weg und bleib in dem dazugehörigen Terminal.

> **Noch einfacher mit Docker Desktop:** Dort ist ein Kubernetes bereits eingebaut, ganz ohne k3d → [DOCKER-DESKTOP.md](./DOCKER-DESKTOP.md)

---

## Weg A: k3d in der WSL

Folge einfach dem [Haupt-Readme](./Readme.md). Alle Befehle gibst du im **Ubuntu-Terminal** ein. Ein paar Dinge sind unter Windows gut zu wissen:

### Browser und `localhost`

Das Cluster läuft in der WSL, dein Browser unter Windows. Trotzdem funktioniert **http://localhost:8080** im Windows-Browser – die WSL leitet `localhost` automatisch weiter. Das kennst du schon von `docker run -p 8080:80` aus Kapitel 06.

Auch die Adressen aus den Zusatzaufgaben (`http://apache.localhost:8080`, `http://adminer.localhost:8080`) funktionieren in **Chrome**, **Edge** und **Firefox** ohne weitere Einstellung.

### Nach einem Neustart

Nach einem Neustart von Windows oder nach `wsl --shutdown` ist dein Cluster **angehalten**, aber nicht gelöscht:

```bash
k3d cluster list
```

**Das solltest du sehen** – bei `SERVERS` und `AGENTS` steht `0/1` bzw. `0/2`, es läuft also nichts:

```
NAME   SERVERS   AGENTS   LOADBALANCER
kurs   0/1       0/2      true
```

Wieder starten:

```bash
k3d cluster start kurs
kubectl get nodes
```

Nach bis zu einer Minute stehen alle drei Nodes wieder auf `Ready`, und alle Deployments sind wieder da.

Meldet `k3d` stattdessen `Cannot connect to the Docker daemon`, läuft Docker in der WSL noch nicht:

```bash
sudo systemctl start docker
```

### Arbeitsspeicher

Die WSL darf standardmäßig nur einen Teil deines Arbeitsspeichers verwenden. Ein Cluster mit drei Nodes und mehreren Anwendungen braucht etwa **2–4 GB**. Prüfen, wie viel die WSL hat:

```bash
free -h
```

**Das solltest du sehen:** In der Zeile `Mem:` steht unter `total` der Arbeitsspeicher der WSL und unter `available`, wie viel davon noch frei ist:

```
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       2.1Gi       3.9Gi       3.0Mi       1.9Gi       5.6Gi
```

Wird es knapp (Pods bleiben auf `Pending`, alles ist zäh), kannst du der WSL mehr geben. Lege dazu unter **Windows** die Datei `C:\Users\<dein-Benutzer>\.wslconfig` an:

```
[wsl2]
memory=6GB
```

Danach in der **PowerShell** `wsl --shutdown` ausführen, das Ubuntu-Terminal neu öffnen und das Cluster mit `k3d cluster start kurs` wieder starten. `free -h` zeigt jetzt den neuen Wert.

### Dateien bearbeiten

Lege den Projektordner **im Linux-Dateisystem** an (`~/k8s-kurs`), nicht unter `/mnt/c/...`. Mit `code .` öffnest du ihn wie gewohnt in VS Code.

---

## Weg B: k3d in der PowerShell mit Docker Desktop

### Voraussetzungen

- **Docker Desktop** ist installiert und läuft (unten links steht **Engine running**). Die Installation ist in [DOCKER-DESKTOP.md](./DOCKER-DESKTOP.md), Schritt 1, beschrieben
- Das in Docker Desktop eingebaute Kubernetes kann **ausgeschaltet** bleiben – k3d bringt sein eigenes mit
- **Port 8080** ist frei

### Schritt 1: kubectl und k3d installieren

Öffne die **PowerShell** (nicht als Administrator nötig). Mit dem in Windows eingebauten Paketmanager **winget**:

```powershell
winget install -e --id Kubernetes.kubectl
winget install -e --id k3d.k3d
```

**Schließe die PowerShell und öffne sie neu**, damit Windows die neuen Programme findet. Dann prüfen:

```powershell
kubectl version --client
k3d version
```

**Das solltest du sehen** (die Versionsnummern können bei dir neuer sein):

```
Client Version: v1.37.1
Kustomize Version: v5.8.1

k3d version v5.9.0
k3s version v1.35.5-k3s1 (default)
```

> **Alternativen**, falls du einen anderen Paketmanager verwendest:
>
> - [Chocolatey](https://chocolatey.org): `choco install kubernetes-cli k3d`
> - [Scoop](https://scoop.sh): `scoop install kubectl k3d`

> **Hinweis:** Docker Desktop bringt ein eigenes `kubectl` mit. Zeigt `kubectl version --client` eine deutlich ältere Version als erwartet, verwendet Windows dieses. Für den Kurs ist das kein Problem.

### Schritt 2: Das Cluster erstellen

```powershell
k3d cluster create kurs --agents 2 -p "8080:80@loadbalancer"
```

Das ist derselbe Befehl wie im Haupt-Readme (dort wird er in Aufgabe 2 erklärt). Beim ersten Mal fragt die **Windows-Firewall** eventuell, ob Docker auf das Netzwerk zugreifen darf – **Zugriff zulassen**.

**Das solltest du am Ende sehen:**

```
INFO[0025] Cluster 'kurs' created successfully!
```

```powershell
kubectl get nodes
```

```
NAME                STATUS   ROLES           AGE   VERSION
k3d-kurs-agent-0    Ready    <none>          18s   v1.35.5+k3s1
k3d-kurs-agent-1    Ready    <none>          17s   v1.35.5+k3s1
k3d-kurs-server-0   Ready    control-plane   26s   v1.35.5+k3s1
```

Drei Nodes mit `Ready` – dein Cluster läuft.

### Schritt 3: Weiter im Haupt-Readme

Mach im [Haupt-Readme](./Readme.md) bei **Aufgabe 2, Schritt 2** weiter. Alle `kubectl`-, `k3d`- und `docker`-Befehle sind in der PowerShell **identisch**. Nur bei den Linux-Befehlen drumherum musst du umdenken:

| Im Haupt-Readme (Bash)                                    | In der PowerShell                                                              |
| --------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `mkdir -p ~/k8s-kurs/k8s/webseite`                        | `mkdir ~\k8s-kurs\k8s\webseite`                                                |
| `cd ~/k8s-kurs`                                           | `cd ~\k8s-kurs`                                                                |
| `curl -s http://localhost:8080`                           | `curl.exe -s http://localhost:8080`                                            |
| `curl -H "Host: apache.localhost" http://localhost:8080`  | `curl.exe -H "Host: apache.localhost" http://localhost:8080`                   |
| `for i in 1 2 3 4 5 6; do curl -s … > /dev/null; done`    | `1..6 \| ForEach-Object { curl.exe -s http://localhost:8080 > $null }`         |
| Befehl über mehrere Zeilen mit `\` am Zeilenende          | Mit einem **Backtick** `` ` `` am Zeilenende                                   |
| `kubectl get pods \| grep webseite`                       | `kubectl get pods \| Select-String webseite`                                   |
| `nano datei.yaml`                                         | `code datei.yaml` oder `notepad datei.yaml`                                    |
| `kubectl get secret … -o jsonpath='{…}' \| base64 -d`     | siehe unten                                                                    |

> **Warum `curl.exe`?** In der älteren **Windows PowerShell 5** ist `curl` nur ein anderer Name für den Befehl `Invoke-WebRequest`, der anders funktioniert. Mit `curl.exe` bekommst du sicher das echte `curl`.

**Ein Secret dekodieren** (Zusatzaufgabe 3). In der PowerShell gibt es kein `base64`, deshalb:

```powershell
$wert = kubectl get secret db-zugang -o jsonpath='{.data.POSTGRES_PASSWORD}'
[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($wert))
```

**Das solltest du sehen:** `geheim123`

**Pfade in `kubectl`:** Schrägstriche funktionieren auch unter Windows. `kubectl apply -f k8s/webseite/` kannst du genau so eingeben.

**SQL-Befehl in Zusatzaufgabe 3:** Der lange `kubectl exec … psql -c "…"`-Befehl enthält einfache Anführungszeichen **innerhalb** von doppelten – das funktioniert in der PowerShell unverändert. Am einfachsten ist es aber, die SQL-Befehle in **Adminer** im Browser einzugeben.

### Aufräumen

```powershell
k3d cluster delete kurs
```

**Das solltest du sehen:** `Successfully deleted cluster kurs!` – in Docker Desktop sind unter **Containers** alle Einträge mit `k3d-kurs-…` verschwunden.

---

## Fehlerbehebung (Windows)

| Problem                                                                             | Mögliche Ursache und Lösung                                                                                                                                       |
| ----------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `k3d : Die Benennung "k3d" wurde nicht als Name eines Cmdlet … erkannt`             | PowerShell nach der Installation nicht neu geöffnet → schließen und neu öffnen                                                                                     |
| `error during connect … open //./pipe/docker_engine: The system cannot find the file specified` | Docker Desktop läuft nicht → starten und warten, bis **Engine running** erscheint                                                                      |
| `Cannot connect to the Docker daemon` in der **WSL**                                | Docker in der WSL läuft nicht → `sudo systemctl start docker`; ist systemd aktiv? (Kapitel 06, Aufgabe 1, Schritt 0)                                               |
| `Cluster creation FAILED, all changes have been rolled back!` (davor `port is already allocated`) | Ein anderer Container belegt Port 8080 → `docker ps`, Container stoppen und den Befehl wiederholen, oder anderen Port wählen: `-p "9080:80@loadbalancer"` (dann überall `localhost:9080` verwenden) |
| `Ports are not available … bind: An attempt was made to access a socket in a way forbidden by its access permissions` | Windows hat den Port **reserviert** (passiert bei Hyper-V/WSL gelegentlich) → `netsh interface ipv4 show excludedportrange protocol=tcp` zeigt die gesperrten Bereiche; einen Port außerhalb wählen |
| Herausfinden, **welches Programm** einen Port belegt                                | `netstat -ano \| findstr :8080` – die letzte Spalte ist die Prozess-ID, im Task-Manager unter **Details** nachsehen                                                |
| `http://localhost:8080` lädt im Windows-Browser nicht, in der WSL mit `curl` aber schon | Die `localhost`-Weiterleitung der WSL hängt → in der PowerShell `wsl --shutdown`, Ubuntu neu öffnen, `k3d cluster start kurs`                                   |
| `http://apache.localhost:8080` wird nicht gefunden                                  | Der Browser löst `*.localhost` nicht auf → Chrome, Edge oder Firefox verwenden, oder mit `curl.exe -H "Host: apache.localhost" http://localhost:8080` testen        |
| `curl` in der PowerShell gibt ein seltsames Objekt oder eine Sicherheitsabfrage aus | Du hast `Invoke-WebRequest` erwischt → `curl.exe` schreiben                                                                                                        |
| YAML-Fehler, obwohl die Datei richtig aussieht                                      | Der Editor hat **Tabs** eingefügt oder die Datei als `datei.yaml.txt` gespeichert → in VS Code bearbeiten, unten rechts „Spaces: 2“                                 |
| `kubectl` zeigt die Nodes eines anderen Clusters (z. B. `docker-desktop`)           | Falscher Kontext → `kubectl config use-context k3d-kurs`                                                                                                           |
| In der WSL und in der PowerShell sieht `kubectl` unterschiedliche Cluster           | Normal: Die WSL (`~/.kube/config`) und Windows (`C:\Users\<du>\.kube\config`) haben **getrennte** Konfigurationen → im Terminal bleiben, in dem das Cluster erstellt wurde |
| Alles ist sehr langsam, Pods bleiben auf `Pending`                                  | Zu wenig Arbeitsspeicher → Weg A: `.wslconfig` anpassen (siehe oben); Weg B: Docker Desktop **Settings → Resources**; oder das Cluster mit `--agents 1` erstellen   |
