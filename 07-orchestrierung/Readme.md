# Kubernetes & k3d: Container orchestrieren

Im letzten Kapitel hast du **einen** Container auf **einem** Server gestartet. Das funktioniert – aber was, wenn der Container nachts abstürzt? Wenn der ganze Server ausfällt? Wenn plötzlich zehnmal so viele Besucher kommen und du fünf Kopien deiner Webseite brauchst? Und wie spielst du ein Update ein, ohne dass die Seite kurz weg ist?

Genau dafür gibt es **Container-Orchestrierung**. In diesem Kapitel startest du mit **k3d** ein komplettes **Kubernetes-Cluster** auf deinem Laptop, lässt deine Webseite aus Kapitel 06 darin in **mehreren Kopien** laufen, machst sie über einen **Service** und einen **Ingress** erreichbar und spielst ein **Update ohne Ausfall** ein.

> **Andere Wege zum Cluster:**
>
> - Du arbeitest unter Windows und möchtest wissen, was dort zu beachten ist – oder du arbeitest **ohne** WSL in der PowerShell? → [K3D-WINDOWS.md](./K3D-WINDOWS.md)
> - Du möchtest statt k3d das in **Docker Desktop** eingebaute Kubernetes verwenden? → [DOCKER-DESKTOP.md](./DOCKER-DESKTOP.md)

## Grundbegriffe

### Was ist Orchestrierung?

Ein **Orchestrator** übernimmt die Arbeit, die du in Kapitel 06 von Hand gemacht hast: Container starten, überwachen, neu starten, auf mehrere Server verteilen und aktualisieren. Du sagst nicht mehr „starte diesen Container“, sondern beschreibst einen **Wunschzustand**:

> „Von meiner Webseite sollen **immer 3 Kopien** laufen.“

Der Orchestrator vergleicht ständig den **Ist-Zustand** mit dem **Wunschzustand** und gleicht Unterschiede selbst aus. Stürzt eine Kopie ab, startet er eine neue – auch nachts um drei, ohne dass dich jemand anruft.

> **Vergleich:** Ein **Thermostat**. Du stellst 21 °C ein (Wunschzustand) und drehst nicht selbst an der Heizung. Wird es kälter (Ist-Zustand weicht ab), heizt der Thermostat von allein nach.

### Was ist Kubernetes?

**Kubernetes** (kurz **K8s** – zwischen K und s stehen 8 Buchstaben) ist der mit Abstand bekannteste Orchestrator. Es wurde ursprünglich von Google entwickelt und ist Open Source. Praktisch jeder Cloud-Anbieter bietet es als fertigen Dienst an, zum Beispiel AWS als **EKS**.

### Was sind k3s und k3d?

Ein „echtes“ Kubernetes-Cluster besteht aus mehreren Servern und ist aufwendig einzurichten. Zum Lernen gibt es eine Abkürzung:

- **k3s** ist eine sehr schlanke, aber vollwertige Kubernetes-Variante.
- **k3d** startet k3s **in Docker-Containern**. Jeder „Server“ (Node) deines Clusters ist dann einfach ein Container auf deinem Laptop.

So bekommst du in unter einer Minute ein Cluster mit mehreren Nodes – und kannst es genauso schnell wieder löschen.

### Die wichtigsten Kubernetes-Begriffe

| Begriff                         | Bedeutung                                                                                         | Vergleich                                |
| ------------------------------- | ------------------------------------------------------------------------------------------------- | ---------------------------------------- |
| **Cluster**                     | Alle Rechner, die zusammen von Kubernetes verwaltet werden                                        | Die ganze Firma                          |
| **Node**                        | Ein einzelner Rechner im Cluster (VM oder bei k3d ein Container)                                  | Ein Mitarbeiter                          |
| **Control Plane** (_Server_)    | Das „Gehirn“: nimmt deine Wünsche entgegen und verteilt die Arbeit                                | Die Geschäftsleitung                     |
| **Worker** (_Agent_)            | Ein Node, auf dem deine Anwendungen tatsächlich laufen                                            | Die Werkstatt                            |
| **Pod**                         | Die kleinste Einheit: ein (selten mehrere) Container mit eigener IP-Adresse                       | Ein Arbeitsplatz                         |
| **Deployment**                  | Sorgt dafür, dass immer die gewünschte **Anzahl** Pods einer Anwendung läuft, und steuert Updates | Der Schichtplan                          |
| **ReplicaSet**                  | Wird vom Deployment erzeugt und zählt die Pods nach. Du fasst es selten direkt an                 | Der Vorarbeiter, der durchzählt          |
| **Service**                     | Eine **feste Adresse** für eine Gruppe von Pods, verteilt Anfragen auf alle                       | Die zentrale Telefonnummer der Abteilung |
| **Ingress**                     | Leitet HTTP-Anfragen **von außen** an den richtigen Service weiter                                | Der Empfang am Haupteingang              |
| **Namespace**                   | Ein abgetrennter Bereich im Cluster, z. B. pro Team oder Projekt                                  | Eine Etage im Bürogebäude                |
| **ConfigMap**                   | Konfiguration (Texte, Dateien), getrennt vom Image gespeichert                                    | Der Aushang am schwarzen Brett           |
| **Secret**                      | Wie eine ConfigMap, aber für Vertrauliches (Passwörter, Tokens)                                   | Der Tresor                               |
| **PersistentVolumeClaim (PVC)** | Die Anforderung „ich brauche Speicher, der Pods überlebt“                                         | Der Antrag auf einen Aktenschrank        |
| **Manifest**                    | Eine **YAML-Datei**, die den Wunschzustand eines Objekts beschreibt                               | Der schriftliche Auftrag                 |
| **kubectl**                     | Das Kommandozeilenprogramm, mit dem du mit dem Cluster sprichst                                   | Das Telefon zur Geschäftsleitung         |
| **Label**                       | Ein Etikett wie `app: webseite`. Darüber finden Deployments und Services „ihre“ Pods              | Das Namensschild                         |

### Von Docker Compose zu Kubernetes

Vieles kennst du schon aus Kapitel 06 – es heißt nur anders:

| Docker / Compose                  | Kubernetes                                   |
| --------------------------------- | -------------------------------------------- |
| Container                         | **Pod**                                      |
| `services:` in der `compose.yaml` | **Deployment** + **Service**                 |
| `ports: "8080:80"`                | **Service** + **Ingress**                    |
| Service-Name als Hostname (`db`)  | Name des **Service** als Hostname (`db`)     |
| `environment:`                    | **ConfigMap** / **Secret**                   |
| `volumes:` (Named Volume)         | **PersistentVolumeClaim**                    |
| `deploy.resources.limits`         | `resources.limits`                           |
| `restart: unless-stopped`         | Standard – Kubernetes startet Pods immer neu |
| `docker compose up -d`            | `kubectl apply -f <Datei oder Ordner>`       |
| `docker compose down`             | `kubectl delete -f <Datei oder Ordner>`      |
| läuft auf **einem** Rechner       | verteilt auf **viele** Rechner               |

### Das Gesamtbild

```
  Dein Laptop
 ┌─────────────────────────────────────────────────────────────────────────┐
 │  Browser ──▶ http://localhost:8080                                      │
 │                     │                                                   │
 │  Docker             ▼                                                   │
 │ ┌───────────────────────────────────────────────────────────────────┐   │
 │ │ k3d-Cluster „kurs“      Loadbalancer (8080 ──▶ 80)                │   │
 │ │                               │                                   │   │
 │ │                               ▼                                   │   │
 │ │                     Ingress (Traefik)                             │   │
 │ │                               │                                   │   │
 │ │                               ▼                                   │   │
 │ │                     Service „webseite“                            │   │
 │ │              ┌────────────────┼────────────────┐                  │   │
 │ │              ▼                ▼                ▼                  │   │
 │ │ ┌──────────────────┐ ┌─────────────────┐ ┌─────────────────┐      │   │
 │ │ │ Node: server-0   │ │ Node: agent-0   │ │ Node: agent-1   │      │   │
 │ │ │ (Control Plane)  │ │                 │ │                 │      │   │
 │ │ │  ┌────────────┐  │ │ ┌────────────┐  │ │ ┌────────────┐  │      │   │
 │ │ │  │ Pod        │  │ │ │ Pod        │  │ │ │ Pod        │  │      │   │
 │ │ │  │ webseite   │  │ │ │ webseite   │  │ │ │ webseite   │  │      │   │
 │ │ │  └────────────┘  │ │ └────────────┘  │ │ └────────────┘  │      │   │
 │ │ └──────────────────┘ └─────────────────┘ └─────────────────┘      │   │
 │ │        ▲ jeder Node ist ein Docker-Container                      │   │
 │ └───────────────────────────────────────────────────────────────────┘   │
 │                                                                         │
 │  Terminal: kubectl ──▶ spricht mit der Control Plane                    │
 └─────────────────────────────────────────────────────────────────────────┘
```

## Voraussetzungen

- **WSL mit Ubuntu** (siehe Kapitel 01) – auf macOS oder Linux funktioniert alles genauso im normalen Terminal
- **Docker** ist installiert und läuft ohne `sudo` (siehe Kapitel 06, Aufgabe 1). Prüfen mit `docker run hello-world`
- Du weißt, wie man ein Image baut (`docker build`, Kapitel 06, Aufgabe 3)
- Mindestens **4 GB freier Arbeitsspeicher** – ein Cluster braucht mehr als ein einzelner Container
- **Port 8080** ist frei. Läuft noch ein Container aus Kapitel 06? Mit `docker ps` prüfen und ggf. mit `docker stop <Name>` anhalten

## Überblick: Was machst du in diesem Kapitel?

| Aufgabe             | Inhalt                                               | Ergebnis                                           |
| ------------------- | ---------------------------------------------------- | -------------------------------------------------- |
| **1**               | `kubectl` und `k3d` installieren                     | Beide Programme zeigen ihre Version an             |
| **2**               | Ein Cluster mit 3 Nodes erstellen                    | `kubectl get nodes` zeigt 3 Nodes mit `Ready`      |
| **3**               | Einen einzelnen Pod starten, ansehen, löschen        | Du kennst die wichtigsten `kubectl`-Befehle        |
| **4**               | Deine Webseite als **Deployment** mit 3 Pods         | Pods heilen sich selbst und lassen sich skalieren  |
| **5**               | **Service** und **Ingress**                          | Die Webseite läuft unter `http://localhost:8080`   |
| **6**               | **Rolling Update** und **Rollback**                  | Version 2.0 ohne Ausfall, zurück zu 1.0            |
| Zusatzaufgaben 1–4  | Zweite Anwendung, ConfigMap, Node-Ausfall, Datenbank | Für alle, die schneller fertig sind                |

Die Aufgaben bauen **aufeinander auf** – bearbeite sie der Reihe nach.

In vielen Schritten brauchst du **zwei Terminals**: eines zum Eingeben von Befehlen und eines, in dem du live zusiehst. Öffne dafür einfach ein zweites Ubuntu-Fenster (bzw. einen zweiten Tab).

---

## Aufgabe 1: kubectl und k3d installieren

Du brauchst zwei Programme:

- **kubectl** – damit steuerst du **jedes** Kubernetes-Cluster, egal ob auf dem Laptop oder in der Cloud
- **k3d** – damit erstellst und löschst du dein lokales Cluster

### Schritt 1: kubectl installieren

```bash
cd ~
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

- Zeile 2: die aktuelle stabile Version von `kubectl` herunterladen. Der Teil `$(curl ...)` fragt zuerst die neueste Versionsnummer ab
- Zeile 3: die Datei nach `/usr/local/bin` kopieren und ausführbar machen
- Zeile 4: die heruntergeladene Datei im Benutzerverzeichnis wieder löschen

> **ARM-Prozessor?** Zeigt `uname -m` bei dir `aarch64` an, ersetze in Zeile 2 `amd64` durch `arm64`.

Prüfen:

```bash
kubectl version --client
```

**Das solltest du sehen** (die Versionsnummern können bei dir neuer sein):

```
Client Version: v1.37.1
Kustomize Version: v5.8.1
```

### Schritt 2: k3d installieren

```bash
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
```

**Das solltest du sehen:**

```
Preparing to install k3d into /usr/local/bin
k3d installed into /usr/local/bin/k3d
Run 'k3d --help' to see what you can do with it.
```

Prüfen:

```bash
k3d version
```

```
k3d version v5.9.0
k3s version v1.35.5-k3s1 (default)
```

> **Erinnerung aus Kapitel 06:** Hier führst du ein Skript aus dem Internet aus, ohne es gelesen zu haben. Für ein Lernprojekt ist das in Ordnung – du kannst es dir aber vorher ansehen: einfach die Adresse im Browser öffnen.

> **macOS:** Mit [Homebrew](https://brew.sh) geht beides in einem Befehl: `brew install kubectl k3d`. Hast du k3d schon länger installiert, aktualisiere es mit `brew upgrade k3d` – diese Anleitung setzt **k3d 5.9 oder neuer** voraus.

---

## Aufgabe 2: Dein erstes Cluster

### Schritt 1: Das Cluster erstellen

```bash
k3d cluster create kurs --agents 2 -p "8080:80@loadbalancer"
```

| Teil                        | Bedeutung                                                                                                          |
| --------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `k3d cluster create`        | Ein neues Cluster erstellen                                                                                        |
| `kurs`                      | Der Name des Clusters                                                                                              |
| `--agents 2`                | Zusätzlich zum **Server** (Control Plane) zwei **Agents** (Worker) starten – also insgesamt 3 Nodes                |
| `-p "8080:80@loadbalancer"` | **Port 8080 deines Rechners** an **Port 80 des Clusters** weiterleiten – das Prinzip kennst du von `docker run -p` |

Beim ersten Mal lädt k3d einige Images herunter, das kann ein bis zwei Minuten dauern. **Das solltest du am Ende sehen:**

```
INFO[0025] Cluster 'kurs' created successfully!
INFO[0025] You can now use it like this:
kubectl cluster-info
```

### Schritt 2: Das Cluster ansehen

```bash
kubectl get nodes
```

**Das solltest du sehen:**

```
NAME                STATUS   ROLES           AGE   VERSION
k3d-kurs-agent-0    Ready    <none>          18s   v1.35.5+k3s1
k3d-kurs-agent-1    Ready    <none>          17s   v1.35.5+k3s1
k3d-kurs-server-0   Ready    control-plane   26s   v1.35.5+k3s1
```

Drei Nodes, alle `Ready`. Steht bei einem noch `NotReady`, warte ein paar Sekunden und führe den Befehl erneut aus.

Und jetzt der Blick hinter die Kulissen:

```bash
docker ps
```

**Das solltest du sehen** (gekürzt):

```
IMAGE                            PORTS                                             NAMES
ghcr.io/k3d-io/k3d-proxy:5.9.0   0.0.0.0:8080->80/tcp, 0.0.0.0:54563->6443/tcp     k3d-kurs-serverlb
rancher/k3s:v1.35.5-k3s1                                                           k3d-kurs-agent-1
rancher/k3s:v1.35.5-k3s1                                                           k3d-kurs-agent-0
rancher/k3s:v1.35.5-k3s1                                                           k3d-kurs-server-0
```

Die drei Nodes und `k3d-kurs-serverlb`, der Loadbalancer mit der Port-Weiterleitung `8080->80`. (Eventuell taucht zusätzlich ein Hilfscontainer `k3d-kurs-tools` auf – der ist harmlos.) **Dein ganzes Cluster besteht aus Docker-Containern.**

### Schritt 3: Mit welchem Cluster spricht kubectl?

`kubectl` merkt sich Cluster in sogenannten **Kontexten** (Datei `~/.kube/config`). k3d hat den Kontext `k3d-kurs` angelegt und gleich ausgewählt:

```bash
kubectl config get-contexts
```

**Das solltest du sehen:**

```
CURRENT   NAME       CLUSTER    AUTHINFO         NAMESPACE
*         k3d-kurs   k3d-kurs   admin@k3d-kurs
```

Der Stern `*` in der ersten Spalte markiert den aktiven Kontext. Hast du mehrere Cluster (z. B. zusätzlich Docker Desktop), wechselst du mit `kubectl config use-context <Name>`.

### Schritt 4: Was läuft schon im Cluster?

```bash
kubectl get pods
```

```
No resources found in default namespace.
```

Leer – aber nur im Namespace `default`. Mit `-A` (_all namespaces_) siehst du alles:

```bash
kubectl get pods -A
```

**Das solltest du sehen:**

```
NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE
kube-system   coredns-8db54c48d-xlpz6                   1/1     Running     0          46s
kube-system   helm-install-traefik-crd-x6hpr            0/1     Completed   0          43s
kube-system   helm-install-traefik-nb4cr                0/1     Completed   2          43s
kube-system   local-path-provisioner-5d9d9885bc-qbrkp   1/1     Running     0          46s
kube-system   metrics-server-786d997795-dc8lx           1/1     Running     0          45s
kube-system   svclb-traefik-e7504d6c-42hx5              2/2     Running     0          8s
kube-system   svclb-traefik-e7504d6c-hpq66              2/2     Running     0          8s
kube-system   svclb-traefik-e7504d6c-r8mr8              2/2     Running     0          8s
kube-system   traefik-9bcdbbd9-r9lzl                    1/1     Running     0          8s
```

Im Namespace `kube-system` laufen die Pods, die Kubernetes selbst braucht, zum Beispiel `coredns` (das interne DNS) und `traefik` (der Ingress-Controller, den du in Aufgabe 5 verwendest). Die beiden `helm-install-…`-Pods mit `Completed` haben Traefik installiert und sind fertig – das ist kein Fehler.

> **Wichtig für Aufgabe 5:** Warte, bis beim Pod `traefik-…` in der Spalte `READY` **1/1** steht. Das dauert nach dem Erstellen des Clusters etwa eine halbe Minute.

---

## Aufgabe 3: Der erste Pod und die wichtigsten kubectl-Befehle

Die meisten Befehle kennst du schon – von `docker`:

| Docker                               | kubectl                                |
| ------------------------------------ | -------------------------------------- |
| `docker run --name mein-nginx nginx` | `kubectl run mein-nginx --image=nginx` |
| `docker ps`                          | `kubectl get pods`                     |
| `docker logs mein-nginx`             | `kubectl logs mein-nginx`              |
| `docker exec -it mein-nginx bash`    | `kubectl exec -it mein-nginx -- bash`  |
| `docker inspect mein-nginx`          | `kubectl describe pod mein-nginx`      |
| `docker rm -f mein-nginx`            | `kubectl delete pod mein-nginx`        |

### Schritt 1: Einen Pod starten

```bash
kubectl run mein-nginx --image=nginx
kubectl get pods
```

**Das solltest du sehen:**

```
pod/mein-nginx created
NAME         READY   STATUS              RESTARTS   AGE
mein-nginx   0/1     ContainerCreating   0          0s
```

Der Node muss das Image erst herunterladen. Führe `kubectl get pods` nach ein paar Sekunden erneut aus, bis dort `Running` und `1/1` steht. Mit `-o wide` siehst du zusätzlich die **IP-Adresse** des Pods und auf welchem **Node** er gelandet ist:

```bash
kubectl get pods -o wide
```

```
NAME         READY   STATUS    RESTARTS   AGE   IP          NODE               NOMINATED NODE   READINESS GATES
mein-nginx   1/1     Running   0          6s    10.42.3.3   k3d-kurs-agent-1   <none>           <none>
```

### Schritt 2: Details und Logs ansehen

```bash
kubectl describe pod mein-nginx
```

Die Ausgabe ist lang. Ganz unten steht der Abschnitt **Events** – dort protokolliert Kubernetes, was mit dem Pod passiert ist:

```
Events:
  Type    Reason     Age   From               Message
  ----    ------     ----  ----               -------
  Normal  Scheduled  5s    default-scheduler  Successfully assigned default/mein-nginx to k3d-kurs-agent-1
  Normal  Pulling    5s    kubelet            Pulling image "nginx"
  Normal  Pulled     1s    kubelet            Successfully pulled image "nginx" in 4.248s
  Normal  Created    1s    kubelet            Container created
  Normal  Started    1s    kubelet            Container started
```

**Wenn ein Pod nicht startet, ist das die erste Stelle, an der du nachsiehst.**

```bash
kubectl logs mein-nginx
```

Du siehst die Startmeldungen von nginx (Zeilen mit `[notice]`), genau wie bei `docker logs`.

### Schritt 3: Den Pod erreichen

Der Pod hat zwar eine IP-Adresse, aber die gilt nur **innerhalb** des Clusters. Zum Testen baut `kubectl` einen Tunnel:

```bash
kubectl port-forward pod/mein-nginx 8081:80
```

**Das solltest du sehen:**

```
Forwarding from 127.0.0.1:8081 -> 80
Forwarding from [::1]:8081 -> 80
```

Der Befehl **bleibt stehen** – das ist richtig so, der Tunnel ist offen, solange er läuft. Öffne im Browser **http://localhost:8081**: Du siehst **„Welcome to nginx!“**, und im Terminal erscheint `Handling connection for 8081`.

Beende den Tunnel mit `Strg + C`.

> `port-forward` ist ein Werkzeug **zum Testen und Debuggen**. Für den dauerhaften Zugriff gibt es Services und Ingress (Aufgabe 5).

### Schritt 4: In den Pod hineinschauen

```bash
kubectl exec -it mein-nginx -- bash
```

Die zwei Striche `--` trennen die Optionen von `kubectl` vom Befehl, der im Container laufen soll. Die Eingabezeile ändert sich zu `root@mein-nginx:/#` – du bist im Container. Probiere:

```bash
cat /etc/os-release
ls /usr/share/nginx/html
exit
```

Du siehst ein Debian-System und die Dateien `50x.html` und `index.html`. Mit `exit` bist du wieder in deinem eigenen Terminal.

### Schritt 5: Den Pod löschen

```bash
kubectl delete pod mein-nginx
kubectl get pods
```

**Das solltest du sehen:**

```
pod "mein-nginx" deleted from default namespace
No resources found in default namespace.
```

Der Pod ist weg – und **bleibt** weg. Einen einzeln gestarteten Pod überwacht niemand. Genau das ändert sich jetzt.

---

## Aufgabe 4: Deployment – deine Webseite in drei Kopien

### Schritt 1: Projektordner und Image vorbereiten

```bash
mkdir -p ~/k8s-kurs/k8s/webseite
cd ~/k8s-kurs
code .
```

VS Code öffnet sich mit dem Ordner `k8s-kurs`. Lege darin (direkt im Ordner, **nicht** in `k8s/`) die beiden Dateien an, die du aus Kapitel 06 kennst.

`index.html`:

```html
<!doctype html>
<html lang="de">
  <head>
    <meta charset="UTF-8" />
    <title>Meine Kubernetes-Webseite</title>
  </head>
  <body>
    <h1>Hallo aus Kubernetes! ☸️</h1>
    <p>Diese Seite läuft in einem Pod in einem Kubernetes-Cluster.</p>
    <p>Erstellt von: DEIN NAME</p>
    <p>Version: 1.0</p>
  </body>
</html>
```

Ersetze `DEIN NAME` durch deinen Namen.

`Dockerfile` (großes `D`, ohne Dateiendung):

```dockerfile
# Basis-Image: ein sehr kleines nginx auf Alpine Linux
FROM nginx:alpine

# Unsere Webseite in den Ordner kopieren, aus dem nginx ausliefert
COPY index.html /usr/share/nginx/html/index.html

# Dokumentation: Der Container lauscht auf Port 80
EXPOSE 80
```

Dein Ordner sieht jetzt so aus:

```
k8s-kurs/
├── Dockerfile
├── index.html
└── k8s/
    └── webseite/      (noch leer)
```

Image bauen (im Terminal, im Ordner `~/k8s-kurs`):

```bash
docker build -t meine-webseite:1.0 .
docker images meine-webseite
```

**Das solltest du sehen:** eine Zeile mit `meine-webseite` und dem Tag `1.0`.

> **Musterlösung:** Alle Dateien dieses Kapitels findest du im Ordner [`beispiel/`](./beispiel/).

### Schritt 2: Das Image in das Cluster laden

Das Image liegt jetzt in **deinem** Docker. Die Nodes des Clusters sind aber eigene Container mit **eigenem** Image-Speicher – sie kennen `meine-webseite:1.0` nicht. k3d kann es hineinkopieren:

```bash
k3d image import meine-webseite:1.0 -c kurs
```

**Das solltest du am Ende sehen:**

```
INFO[0003] Successfully imported image(s)
INFO[0003] Successfully imported 1 image(s) into 1 cluster(s)
```

> **Und in echten Projekten?** Dort gibt es kein `image import`. Das Image wird in eine **Registry** hochgeladen (wie in Kapitel 06 zu Docker Hub), und die Nodes laden es von dort. Wenn du dein Image bei Docker Hub hast, kannst du im Manifest auch direkt `<dein-username>/meine-webseite:1.0` verwenden und dir den Import sparen.

### Schritt 3: Das Deployment-Manifest schreiben

Lege in VS Code im Ordner `k8s/webseite/` die Datei `deployment.yaml` an, also `k8s/webseite/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webseite
  labels:
    app: webseite
spec:
  # Wunschzustand: 3 Kopien (Pods) unserer Webseite
  replicas: 3
  # Welche Pods gehören zu diesem Deployment? Alle mit dem Label app=webseite
  selector:
    matchLabels:
      app: webseite
  # Die Vorlage, aus der jeder Pod erstellt wird
  template:
    metadata:
      labels:
        app: webseite
    spec:
      containers:
        - name: webseite
          image: meine-webseite:1.0
          ports:
            - containerPort: 80
```

| Abschnitt             | Bedeutung                                                                  |
| --------------------- | -------------------------------------------------------------------------- |
| `apiVersion` + `kind` | **Was** für ein Objekt ist das? Steht in **jedem** Manifest ganz oben      |
| `metadata.name`       | Der Name des Objekts im Cluster                                            |
| `spec.replicas`       | Wie viele Pods sollen laufen?                                              |
| `spec.selector`       | An welchem **Label** erkennt das Deployment seine Pods?                    |
| `spec.template`       | Die Vorlage für die Pods. Die Labels hier **müssen** zum `selector` passen |
| `containers`          | Welches Image, welcher Port – entspricht den Angaben bei `docker run`      |

> Wie in der `compose.yaml` sind die **Einrückungen** entscheidend: immer **zwei Leerzeichen**, nie Tabs.

### Schritt 4: Das Manifest anwenden

```bash
kubectl apply -f k8s/webseite/deployment.yaml
```

**Das solltest du sehen:**

```
deployment.apps/webseite created
```

`apply` bedeutet: „Sorge dafür, dass das Cluster so aussieht wie in dieser Datei.“ Führe den Befehl ruhig **noch einmal** aus – jetzt steht dort `deployment.apps/webseite unchanged`. Ändert sich nichts an der Datei, passiert auch nichts.

```bash
kubectl get deployments
kubectl get pods -o wide
```

**Das solltest du sehen:**

```
NAME       READY   UP-TO-DATE   AVAILABLE   AGE
webseite   3/3     3            3           6s

NAME                        READY   STATUS    RESTARTS   AGE   IP          NODE
webseite-7f8645ddc6-62fqr   1/1     Running   0          6s    10.42.0.8   k3d-kurs-server-0
webseite-7f8645ddc6-7fcjg   1/1     Running   0          6s    10.42.3.4   k3d-kurs-agent-1
webseite-7f8645ddc6-7jksv   1/1     Running   0          6s    10.42.1.4   k3d-kurs-agent-0
```

Drei Pods, verteilt auf drei Nodes, jeder mit eigener IP. Die Namen setzen sich zusammen aus `<Deployment>-<ReplicaSet>-<zufällig>` – bei dir stehen dort andere Buchstaben.

> Steht in der Spalte `STATUS` etwas wie `ErrImagePull` oder `ImagePullBackOff`? Dann findet das Cluster dein Image nicht: Schritt 2 wiederholen und auf Tippfehler im Image-Namen achten.

### Schritt 5: Selbstheilung ausprobieren

Starte im **zweiten Terminal**:

```bash
kubectl get pods -w
```

`-w` steht für _watch_: Der Befehl bleibt stehen und zeigt jede Änderung als neue Zeile an.

Lösche im **ersten Terminal** einen der Pods (den Namen aus **deiner** Ausgabe kopieren):

```bash
kubectl delete pod webseite-7f8645ddc6-62fqr
kubectl get pods
```

**Das solltest du sehen:**

```
NAME                        READY   STATUS    RESTARTS   AGE
webseite-7f8645ddc6-7fcjg   1/1     Running   0          48s
webseite-7f8645ddc6-7jksv   1/1     Running   0          48s
webseite-7f8645ddc6-mhm92   1/1     Running   0          2s
```

Es sind **sofort wieder drei**. Achte auf die Spalte `AGE`: Einer der Pods ist nur wenige Sekunden alt und hat einen neuen Namen. Das Deployment hat bemerkt, dass der Ist-Zustand (2) vom Wunschzustand (3) abweicht, und einen neuen Pod gestartet. Im zweiten Terminal konntest du das live verfolgen.

### Schritt 6: Skalieren

Mehr Besucher? Ändere in `deployment.yaml` die Zeile `replicas: 3` in `replicas: 5`, **speichere** die Datei und wende sie erneut an:

```bash
kubectl apply -f k8s/webseite/deployment.yaml
kubectl get pods
```

**Das solltest du sehen:** `deployment.apps/webseite configured` und danach **fünf** Pods, zwei davon ganz frisch.

Stelle danach wieder `replicas: 3` ein, speichere und wende die Datei noch einmal an. Im zweiten Terminal siehst du, wie zwei Pods auf `Terminating` wechseln und verschwinden.

> Es gibt auch den schnellen Weg `kubectl scale deployment webseite --replicas=5`. Dann stimmt aber deine Datei nicht mehr mit dem Cluster überein. **Besser: immer die Datei ändern und `apply` ausführen.** So ist die Datei (und damit dein Git-Repository) die eine Wahrheit.

Das zweite Terminal kannst du laufen lassen oder mit `Strg + C` beenden.

---

## Aufgabe 5: Service und Ingress – die Webseite erreichbar machen

Drei Pods laufen, aber im Browser ist noch nichts zu sehen. Probier es aus: **http://localhost:8080** zeigt im Moment nur `404 page not found` – das Cluster antwortet zwar, kennt aber noch keinen Weg zu deinen Pods.

Und selbst im Cluster gäbe es ein Problem: Jeder Pod hat eine **eigene IP**, und die ändert sich bei jedem Neustart. Welche soll man aufrufen?

### Schritt 1: Der Service

Ein **Service** bekommt eine **feste** Adresse und verteilt Anfragen auf alle passenden Pods. Lege `k8s/webseite/service.yaml` an:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webseite
spec:
  # Der Service leitet an alle Pods mit dem Label app=webseite weiter
  selector:
    app: webseite
  ports:
    - port: 80 # Port des Service
      targetPort: 80 # Port im Container
```

```bash
kubectl apply -f k8s/webseite/service.yaml
kubectl get services
```

**Das solltest du sehen:**

```
service/webseite created
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
kubernetes   ClusterIP   10.43.0.1       <none>        443/TCP   101s
webseite     ClusterIP   10.43.157.101   <none>        80/TCP    1s
```

Der Service `webseite` hat eine feste `CLUSTER-IP` bekommen. (Der Service `kubernetes` gehört zum Cluster selbst.) An welche Pods leitet er weiter?

```bash
kubectl describe service webseite
```

Achte auf diese beiden Zeilen:

```
Selector:                 app=webseite
Endpoints:                10.42.0.9:80,10.42.3.4:80,10.42.1.4:80
```

Bei `Endpoints` stehen die IP-Adressen deiner drei Pods (vergleiche mit `kubectl get pods -o wide`). Der Service hat sie über das Label `app: webseite` gefunden. Das Deployment kennt den Service nicht und umgekehrt: **Die einzige Verbindung ist das Label.**

Innerhalb des Clusters ist die Webseite jetzt unter dem Namen `webseite` erreichbar. Teste es mit einem Wegwerf-Pod:

```bash
kubectl run test --rm -it --image=busybox --restart=Never -- wget -qO- http://webseite
```

**Das solltest du sehen:** den HTML-Code deiner Seite und danach `pod "test" deleted`. Wie bei Docker Compose funktioniert der **Service-Name als Hostname**.

### Schritt 2: Der Ingress

Der Service ist nur **im** Cluster erreichbar. Die Tür nach außen ist der **Ingress**. Lege `k8s/webseite/ingress.yaml` an:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: webseite
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: webseite
                port:
                  number: 80
```

Die Regel bedeutet: „Alle Anfragen, deren Pfad mit `/` beginnt (also alle), gehen an den Service `webseite` auf Port 80.“

Du kannst auch einen **ganzen Ordner** auf einmal anwenden:

```bash
kubectl apply -f k8s/webseite/
kubectl get ingress
```

**Das solltest du sehen:**

```
deployment.apps/webseite unchanged
ingress.networking.k8s.io/webseite created
service/webseite unchanged

NAME       CLASS     HOSTS   ADDRESS                            PORTS   AGE
webseite   traefik   *       172.20.0.3,172.20.0.4,172.20.0.5   80      1s
```

Nur der Ingress ist neu – Deployment und Service gab es schon (`unchanged`).

### Schritt 3: Im Browser öffnen 🎉

**http://localhost:8080**

Du siehst **„Hallo aus Kubernetes! ☸️“** mit deinem Namen und **Version: 1.0**.

Der Weg der Anfrage:

```
Browser ─▶ localhost:8080 ─▶ k3d-Loadbalancer ─▶ Traefik (Ingress) ─▶ Service ─▶ einer der 3 Pods
```

> **Was ist Traefik?** Ein Ingress-Manifest allein tut nichts. Es braucht ein Programm, das die Regeln liest und umsetzt: einen **Ingress-Controller**. k3s bringt dafür **Traefik** bereits mit. In anderen Clustern muss man einen Controller selbst installieren.

> Siehst du weiterhin `404 page not found`? Dann warte ein paar Sekunden und lade neu. Hilft das nicht: `kubectl get ingress` (ist der Ingress da?) und `kubectl get pods -n kube-system` (läuft `traefik-…` mit `1/1`?).

### Schritt 4: Die Lastverteilung sichtbar machen

Lass im **zweiten Terminal** die Logs aller drei Pods gleichzeitig anzeigen (ein noch laufendes `kubectl get pods -w` vorher mit `Strg + C` beenden):

```bash
kubectl logs -l app=webseite --prefix -f
```

- `-l app=webseite` – alle Pods mit diesem **Label** (statt eines einzelnen Namens)
- `--prefix` – vor jede Zeile den Pod-Namen schreiben
- `-f` – live mitlesen

Rufe im **ersten Terminal** die Seite sechsmal hintereinander auf:

```bash
for i in 1 2 3 4 5 6; do curl -s http://localhost:8080 > /dev/null; done
```

**Das solltest du im zweiten Terminal sehen** (gekürzt):

```
[pod/webseite-7f8645ddc6-7fcjg/webseite] 10.42.1.3 - - [05/Oct/2026:13:39:07 +0000] "GET / HTTP/1.1" 200 326 "-" "curl/8.5.0"
[pod/webseite-7f8645ddc6-7jksv/webseite] 10.42.1.3 - - [05/Oct/2026:13:39:07 +0000] "GET / HTTP/1.1" 200 326 "-" "curl/8.5.0"
[pod/webseite-7f8645ddc6-mhm92/webseite] 10.42.1.3 - - [05/Oct/2026:13:39:07 +0000] "GET / HTTP/1.1" 200 326 "-" "curl/8.5.0"
[pod/webseite-7f8645ddc6-7fcjg/webseite] 10.42.1.3 - - [05/Oct/2026:13:39:07 +0000] "GET / HTTP/1.1" 200 326 "-" "curl/8.5.0"
```

Achte auf den Pod-Namen in den eckigen Klammern: Die Anfragen landen **abwechselnd bei verschiedenen Pods**. Beenden mit `Strg + C`.

---

## Aufgabe 6: Rolling Update und Rollback

In Kapitel 06 hieß ein Update: Container stoppen, löschen, neu starten – und dazwischen war die Seite kurz **nicht erreichbar**. Kubernetes tauscht die Pods **nacheinander** aus.

### Schritt 1: Version 2.0 bauen und importieren

1. In `index.html` die Zeile `Version: 1.0` in `Version: 2.0` ändern und speichern
2. Image bauen und ins Cluster laden:

```bash
docker build -t meine-webseite:2.0 .
k3d image import meine-webseite:2.0 -c kurs
```

**Das solltest du sehen:** wieder `Successfully imported 1 image(s) into 1 cluster(s)`. Im Browser steht weiterhin **Version: 1.0** – das neue Image liegt bereit, wird aber noch von keinem Pod verwendet.

### Schritt 2: Das Update ausrollen

Starte im **zweiten Terminal** `kubectl get pods -w`.

Ändere in `k8s/webseite/deployment.yaml` die Zeile `image: meine-webseite:1.0` in `image: meine-webseite:2.0`, speichere und wende die Datei im **ersten Terminal** an:

```bash
kubectl apply -f k8s/webseite/deployment.yaml
kubectl rollout status deployment/webseite
```

**Das solltest du im ersten Terminal sehen:**

```
deployment.apps/webseite configured
Waiting for deployment "webseite" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "webseite" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "webseite" rollout to finish: 1 old replicas are pending termination...
deployment "webseite" successfully rolled out
```

**Und im zweiten Terminal** (gekürzt):

```
NAME                        READY   STATUS              RESTARTS   AGE
webseite-7f8645ddc6-7fcjg   1/1     Running             0          46s
webseite-7f8645ddc6-7jksv   1/1     Running             0          46s
webseite-7f8645ddc6-mhm92   1/1     Running             0          40s
webseite-59d67f6bf7-82hnm   0/1     ContainerCreating   0          0s
webseite-59d67f6bf7-82hnm   1/1     Running             0          1s
webseite-7f8645ddc6-7fcjg   1/1     Terminating         0          47s
webseite-59d67f6bf7-jm655   0/1     ContainerCreating   0          0s
webseite-59d67f6bf7-jm655   1/1     Running             0          0s
webseite-7f8645ddc6-7jksv   1/1     Terminating         0          47s
...
```

Ein **neuer** Pod startet (erkennbar am neuen mittleren Namensteil), sobald er `Running` ist, wird ein **alter** beendet – und so weiter, bis alle ausgetauscht sind. Es sind zu jedem Zeitpunkt genug Pods da, um Anfragen zu beantworten.

Browser neu laden (`Strg + F5`): **Version: 2.0**.

### Schritt 3: Rollback

Stell dir vor, Version 2.0 enthält einen Fehler. Kubernetes merkt sich die bisherigen Versionen:

```bash
kubectl rollout history deployment/webseite
```

```
deployment.apps/webseite
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

Zurück zur vorherigen Version:

```bash
kubectl rollout undo deployment/webseite
kubectl rollout status deployment/webseite
```

**Das solltest du sehen:** `deployment.apps/webseite rolled back` und kurz darauf `deployment "webseite" successfully rolled out`. Browser neu laden: wieder **Version: 1.0**.

> **Achtung:** Nach `rollout undo` steht in deiner Datei noch `2.0`, im Cluster läuft aber `1.0`. In echten Projekten macht man ein Rollback deshalb lieber über **Git**: die Änderung an der Datei rückgängig machen und erneut `kubectl apply` ausführen.

Bringe Datei und Cluster wieder in Einklang: Stelle das Image in `deployment.yaml` zurück auf `meine-webseite:1.0`, speichere und führe `kubectl apply -f k8s/webseite/deployment.yaml` aus.

### Schritt 4: Was passiert bei einem kaputten Update?

Trage in `deployment.yaml` ein Image ein, das es nicht gibt – `meine-webseite:9.9` –, speichere und wende die Datei an:

```bash
kubectl apply -f k8s/webseite/deployment.yaml
kubectl get pods
```

**Das solltest du sehen:**

```
NAME                        READY   STATUS         RESTARTS   AGE
webseite-77d5f65947-v6xcj   0/1     ErrImagePull   0          12s
webseite-7f8645ddc6-2l2cj   1/1     Running        0          45s
webseite-7f8645ddc6-fkb25   1/1     Running        0          43s
webseite-7f8645ddc6-g2md5   1/1     Running        0          44s
```

Der neue Pod kommt nicht hoch (`ErrImagePull`, kurz darauf `ImagePullBackOff`). **Die drei alten Pods laufen weiter** – Kubernetes beendet sie erst, wenn die neuen wirklich bereit sind. Lade die Seite im Browser neu: Sie ist die ganze Zeit erreichbar und zeigt **Version: 1.0**.

Die Ursache findest du unter **Events** (den Namen des kaputten Pods aus deiner Ausgabe kopieren):

```bash
kubectl describe pod webseite-77d5f65947-v6xcj
```

```
  Warning  Failed     11s   kubelet   Failed to pull image "meine-webseite:9.9": ... not found
  Warning  Failed     11s   kubelet   Error: ErrImagePull
  Normal   BackOff    10s   kubelet   Back-off pulling image "meine-webseite:9.9"
```

**Reparieren:** In der Datei wieder `meine-webseite:1.0` eintragen, speichern und `kubectl apply -f k8s/webseite/deployment.yaml` ausführen. Mit `kubectl get pods` siehst du danach wieder genau drei Pods mit `Running`.

---

## Zusatzaufgabe 1: Eine zweite Anwendung mit eigenem Hostnamen

In Kapitel 06 lief Apache neben deiner Webseite auf einem **anderen Port** (8081). Mit einem Ingress geht es eleganter: **ein** Port, aber verschiedene **Hostnamen**.

### Schritt 1: Das Manifest schreiben

Lege einen neuen Ordner `k8s/apache/` und darin die Datei `apache.yaml` an, also `k8s/apache/apache.yaml`. Mehrere Objekte in einer Datei trennst du mit `---`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: apache
  labels:
    app: apache
spec:
  replicas: 2
  selector:
    matchLabels:
      app: apache
  template:
    metadata:
      labels:
        app: apache
    spec:
      containers:
        - name: apache
          image: httpd:alpine
          ports:
            - containerPort: 80
          resources:
            requests:
              memory: 32Mi
              cpu: 100m
            limits:
              memory: 64Mi
              cpu: 500m
---
apiVersion: v1
kind: Service
metadata:
  name: apache
spec:
  selector:
    app: apache
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: apache
spec:
  rules:
    # Diese Regel gilt nur für Anfragen an den Hostnamen apache.localhost
    - host: apache.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: apache
                port:
                  number: 80
```

### Schritt 2: Anwenden und aufrufen

```bash
kubectl apply -f k8s/apache/
kubectl get pods
```

**Das solltest du sehen:**

```
deployment.apps/apache created
service/apache created
ingress.networking.k8s.io/apache created

NAME                        READY   STATUS    RESTARTS   AGE
apache-8674d9574-gcw9k      1/1     Running   0          7s
apache-8674d9574-v6cmd      1/1     Running   0          7s
webseite-7f8645ddc6-2l2cj   1/1     Running   0          57s
webseite-7f8645ddc6-fkb25   1/1     Running   0          55s
webseite-7f8645ddc6-g2md5   1/1     Running   0          56s
```

Öffne **http://apache.localhost:8080** – dort steht **„It works!“**. Unter **http://localhost:8080** läuft weiterhin deine Webseite. Traefik entscheidet anhand des **Hostnamens** in der Anfrage, an welchen Service sie geht.

> **Warum funktioniert `apache.localhost`?** Alle Namen, die auf `.localhost` enden, zeigen automatisch auf deinen eigenen Rechner. Klappt das in deinem Browser nicht, teste im Terminal mit `curl -H "Host: apache.localhost" http://localhost:8080`.

### Die Ressourcen

Den Block `resources` kennst du aus der `compose.yaml` als `deploy.resources.limits`. Neu ist `requests`:

- `requests` – das bekommt der Pod **mindestens**. Kubernetes wählt danach einen Node aus, der noch so viel frei hat
- `limits` – die **Obergrenze**. Braucht der Container mehr Arbeitsspeicher, wird er beendet (`OOMKilled`) und neu gestartet
- `100m` bedeutet 100 **Millicores**, also 0,1 CPU. `Mi` steht für Mebibyte

**Zum Knobeln:** Setze bei `memory` **beide** Werte (`requests` und `limits`) auf `100Gi` und wende die Datei an. In welchem Status bleibt der neue Pod hängen, und was steht bei `kubectl describe pod <Name>` unter Events? Laufen die alten Pods weiter? Stelle danach wieder `32Mi` und `64Mi` ein und wende die Datei erneut an.

<details>
<summary>Lösung</summary>

Der neue Pod bleibt auf `Pending`. Unter Events steht `0/3 nodes are available: 3 Insufficient memory.` – kein Node hat 100 GiB frei, also wird der Pod gar nicht erst gestartet. Die alten Pods laufen weiter, wie beim kaputten Update in Aufgabe 6.

(Setzt du nur `requests` auf `100Gi`, lehnt Kubernetes die Datei direkt ab: `must be less than or equal to memory limit`.)

</details>

## Zusatzaufgabe 2: ConfigMap – eine Webseite ohne eigenes Image

Für jede kleine Textänderung ein neues Image bauen? Mit einer **ConfigMap** speicherst du Dateien **im Cluster** und hängst sie in den Container ein – das Gegenstück zum **Bind Mount** aus Kapitel 06.

### Schritt 1: Das Manifest schreiben

Lege den Ordner `k8s/configmap/` und darin die Datei `hallo.yaml` an, also `k8s/configmap/hallo.yaml`:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: hallo-html
data:
  # Schlüssel = Dateiname, Wert = Inhalt der Datei
  index.html: |
    <!doctype html>
    <html lang="de">
      <head>
        <meta charset="UTF-8" />
        <title>Hallo ConfigMap</title>
      </head>
      <body>
        <h1>Hallo aus einer ConfigMap!</h1>
        <p>Diese Seite steckt nicht im Image, sondern in einer ConfigMap.</p>
        <p>Version: 1.0</p>
      </body>
    </html>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hallo
  labels:
    app: hallo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hallo
  template:
    metadata:
      labels:
        app: hallo
    spec:
      containers:
        - name: nginx
          # Das unveränderte, offizielle Image – kein docker build nötig
          image: nginx:alpine
          ports:
            - containerPort: 80
          volumeMounts:
            # Die ConfigMap als Ordner in den Container einhängen
            - name: html
              mountPath: /usr/share/nginx/html
              readOnly: true
      volumes:
        - name: html
          configMap:
            name: hallo-html
---
apiVersion: v1
kind: Service
metadata:
  name: hallo
spec:
  selector:
    app: hallo
  ports:
    - port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hallo
spec:
  rules:
    - host: hallo.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hallo
                port:
                  number: 80
```

Das `|` hinter `index.html:` bedeutet in YAML: „Jetzt folgt ein mehrzeiliger Text.“ Die Zeilen darunter müssen alle **mindestens vier Leerzeichen** eingerückt sein.

### Schritt 2: Anwenden und aufrufen

```bash
kubectl apply -f k8s/configmap/
```

**Das solltest du sehen:**

```
configmap/hallo-html created
deployment.apps/hallo created
service/hallo created
ingress.networking.k8s.io/hallo created
```

Öffne **http://hallo.localhost:8080** – **„Hallo aus einer ConfigMap!“**, Version: 1.0.

### Schritt 3: Den Inhalt ändern – ohne neues Image

Ändere in `hallo.yaml` die Zeile `Version: 1.0` in `Version: 1.1`, speichere und führe aus:

```bash
kubectl apply -f k8s/configmap/
kubectl rollout restart deployment/hallo
```

**Das solltest du sehen:**

```
configmap/hallo-html configured
deployment.apps/hallo unchanged
service/hallo unchanged
ingress.networking.k8s.io/hallo unchanged
deployment.apps/hallo restarted
```

Nur die ConfigMap hat sich geändert. `rollout restart` tauscht alle Pods einmal aus (wieder als Rolling Update), damit sie sicher die neue ConfigMap verwenden. Browser neu laden: **Version: 1.1** – ohne `docker build`, ohne `k3d image import`.

## Zusatzaufgabe 3: Ein Node fällt aus

Bisher hast du einzelne Pods gelöscht. Was passiert, wenn ein **ganzer Server** ausfällt? Diese Aufgabe braucht etwas Geduld: rund **sechs Minuten**.

### Schritt 1: Einen Node auswählen

Finde heraus, auf welchem Node der Ingress-Controller **Traefik** läuft:

```bash
kubectl get pods -n kube-system -o wide | grep '^traefik'
```

```
traefik-9bcdbbd9-r9lzl   1/1   Running   0   20m   10.42.1.3   k3d-kurs-agent-0   <none>   <none>
```

In diesem Beispiel ist es `k3d-kurs-agent-0`. Stoppe gleich den **anderen** Agent (hier also `k3d-kurs-agent-1`) – sonst fällt mit Traefik die Eingangstür des Clusters aus, und das ist ein anderes Experiment.

### Schritt 2: Den Node stoppen und zusehen

Im **zweiten Terminal**:

```bash
kubectl get pods -o wide -w
```

Im **ersten Terminal** (den Namen ggf. anpassen, siehe Schritt 1):

```bash
k3d node stop k3d-kurs-agent-1
kubectl get nodes
```

**Was du nacheinander siehst:**

| Wann                    | Was passiert                                                                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| sofort                  | Noch nichts: Der Node steht weiter auf `Ready`, alle Pods auf `Running`. Kubernetes hat den Ausfall noch nicht bemerkt                     |
| nach ca. **45 Sekunden** | `kubectl get nodes` zeigt den Node als **`NotReady`**. Seine Pods bekommen ab jetzt keine Anfragen mehr                                    |
| nach ca. **5 Minuten**  | Die Pods des ausgefallenen Nodes wechseln auf `Terminating`, und auf den verbleibenden Nodes entstehen **neue** Pods als Ersatz            |

Kubernetes wartet absichtlich rund fünf Minuten, ob der Node zurückkommt – er könnte ja nur kurz neu starten.

Lade währenddessen ein paarmal **http://localhost:8080** neu: Die Seite bleibt erreichbar, weil die Pods auf den anderen Nodes weiterlaufen. In den ersten Sekunden nach dem Ausfall kann eine einzelne Anfrage hängen bleiben.

### Schritt 3: Den Node wieder starten

```bash
k3d node start k3d-kurs-agent-1
kubectl get nodes
```

Nach wenigen Sekunden ist der Node wieder `Ready`, und die Pods mit `Terminating` verschwinden. Mit `kubectl get pods -o wide` siehst du: Es laufen wieder genau so viele Pods wie gewünscht – jetzt aber nur auf zwei Nodes verteilt. Kubernetes verschiebt laufende Pods nicht von selbst zurück.

**Zum Knobeln:** Warum ist `replicas: 1` für eine Anwendung, die immer erreichbar sein soll, keine gute Idee?

## Zusatzaufgabe 4 (für Fortgeschrittene): PostgreSQL mit Secret und Volume

Zum Schluss das Beispiel aus der Bonusaufgabe von Kapitel 06: **PostgreSQL** und **Adminer** – diesmal in Kubernetes.

```
   Browser ──▶ adminer.localhost:8080 ──▶ Ingress ──▶ ┌─────────┐  db:5432  ┌──────────┐     ┌──────────┐
                                                      │ adminer │ ────────▶ │ postgres │ ──▶ │ db-daten │
                                                      └─────────┘  Service  └──────────┘     │  (PVC)   │
                                                                     „db“        ▲           └──────────┘
                                                                                 │
                                                                        Secret „db-zugang“
```

Lege zuerst den Ordner `k8s/datenbank/` an. Darin entstehen drei Dateien.

### Schritt 1: Das Secret

`k8s/datenbank/secret.yaml`:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-zugang
type: Opaque
# stringData: Werte im Klartext, Kubernetes wandelt sie beim Speichern in Base64 um
stringData:
  POSTGRES_USER: app
  POSTGRES_PASSWORD: geheim123
  POSTGRES_DB: kursdb
```

### Schritt 2: Datenbank mit Volume

`k8s/datenbank/postgres.yaml`:

```yaml
# PersistentVolumeClaim (PVC): "Ich brauche 1 GiB Speicher, der Pods überlebt"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: db-daten
spec:
  accessModes:
    - ReadWriteOnce # von einem Node gleichzeitig les- und schreibbar
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: db
  labels:
    app: db
spec:
  replicas: 1
  # Erst den alten Pod beenden, dann den neuen starten
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: db
  template:
    metadata:
      labels:
        app: db
    spec:
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports:
            - containerPort: 5432
          # Alle Schlüssel aus dem Secret als Umgebungsvariablen übernehmen
          envFrom:
            - secretRef:
                name: db-zugang
          volumeMounts:
            - name: daten
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: daten
          persistentVolumeClaim:
            claimName: db-daten
---
# Der Service heißt "db" – unter genau diesem Namen erreichen andere Pods die Datenbank
apiVersion: v1
kind: Service
metadata:
  name: db
spec:
  selector:
    app: db
  ports:
    - port: 5432
      targetPort: 5432
```

Neu dabei:

- **PersistentVolumeClaim** – entspricht dem Named Volume `db-daten` aus der `compose.yaml`. Du forderst nur Speicher an; **woher** er kommt (lokale Festplatte, Cloud-Speicher …), entscheidet das Cluster
- `envFrom.secretRef` – ersetzt den `environment`-Block. Das Passwort steht nicht mehr im Deployment
- `strategy: Recreate` – bei einer Datenbank darf es **kein** Rolling Update geben, sonst würden kurz zwei Datenbanken auf denselben Dateien arbeiten
- Für die Datenbank gibt es **keinen Ingress** – sie soll nur im Cluster erreichbar sein, genau wie in Kapitel 06 ohne `ports`

### Schritt 3: Adminer

`k8s/datenbank/adminer.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: adminer
  labels:
    app: adminer
spec:
  replicas: 1
  selector:
    matchLabels:
      app: adminer
  template:
    metadata:
      labels:
        app: adminer
    spec:
      containers:
        - name: adminer
          image: adminer
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: adminer
spec:
  selector:
    app: adminer
  ports:
    - port: 80 # Port des Service
      targetPort: 8080 # Adminer lauscht im Container auf Port 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: adminer
spec:
  rules:
    - host: adminer.localhost
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: adminer
                port:
                  number: 80
```

### Schritt 4: Starten und prüfen

```bash
kubectl apply -f k8s/datenbank/
```

**Das solltest du sehen:**

```
deployment.apps/adminer created
service/adminer created
ingress.networking.k8s.io/adminer created
persistentvolumeclaim/db-daten created
deployment.apps/db created
service/db created
secret/db-zugang created
```

Die Images müssen erst heruntergeladen werden. Wiederhole den folgenden Befehl, bis beide Pods `Running` sind (das kann eine Minute dauern):

```bash
kubectl get pods,pvc
```

```
NAME                            READY   STATUS    RESTARTS   AGE
pod/adminer-5785b77798-jnzrx    1/1     Running   0          14s
pod/db-5cc9fd6d77-k88gb         1/1     Running   0          14s
...

NAME                             STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
persistentvolumeclaim/db-daten   Bound    pvc-fea214ae-a22a-4b50-a24d-9af484378fe1   1Gi        RWO            local-path
```

Beim PVC steht `Bound`: Das Cluster hat den angeforderten Speicher bereitgestellt.

Prüfe in den Logs, ob die Datenbank bereit ist:

```bash
kubectl logs deploy/db
```

Ganz unten muss stehen: `database system is ready to accept connections`.

### Schritt 5: Ein Blick auf das Secret

```bash
kubectl get secret db-zugang -o yaml
```

**Das solltest du sehen** (Ausschnitt):

```yaml
data:
  POSTGRES_DB: a3Vyc2Ri
  POSTGRES_PASSWORD: Z2VoZWltMTIz
  POSTGRES_USER: YXBw
```

Die Werte sehen kryptisch aus. Das ist aber **keine Verschlüsselung**, sondern nur **Base64** – das kann jeder zurückrechnen:

```bash
kubectl get secret db-zugang -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d
```

```
geheim123
```

Sieh dir die Ausgabe von `-o yaml` noch einmal genau an: Unter `annotations` steht das Passwort sogar **im Klartext**, weil `kubectl apply` sich dort den Inhalt deiner Datei merkt.

> Der Vorteil eines Secrets liegt woanders: Das Passwort steht nicht im Deployment, und im Cluster kann man genau festlegen, **wer** Secrets lesen darf. Die Datei `secret.yaml` selbst gehört in echten Projekten **nicht** ins Git-Repository.

### Schritt 6: Mit Adminer anmelden

**http://adminer.localhost:8080** öffnen und eintragen:

| Feld         | Wert                             |
| ------------ | -------------------------------- |
| **System**   | `PostgreSQL`                     |
| **Server**   | `db` (ist bereits vorausgefüllt) |
| **Username** | `app`                            |
| **Password** | `geheim123`                      |
| **Database** | `kursdb`                         |

Nach dem Klick auf **Login** siehst du die (noch leere) Datenbank `kursdb` mit dem Schema `public`. Der Server heißt `db` – das ist der Name des **Service**.

### Schritt 7: Der Beweis – Pod löschen, Daten behalten

Lege Daten an. Entweder in Adminer links unter **SQL command** oder direkt im Terminal:

```bash
kubectl exec deploy/db -- psql -U app -d kursdb -c "CREATE TABLE teilnehmer (id SERIAL PRIMARY KEY, name TEXT NOT NULL); INSERT INTO teilnehmer (name) VALUES ('Alice'), ('Bob');"
```

```
CREATE TABLE
INSERT 0 2
```

Jetzt den Datenbank-Pod löschen. Das Deployment startet sofort einen neuen:

```bash
kubectl delete pod -l app=db
kubectl get pods
```

Der `db-…`-Pod hat einen **neuen Namen** und ist erst wenige Sekunden alt. Warte kurz, bis er `Running` ist, dann:

```bash
kubectl exec deploy/db -- psql -U app -d kursdb -c "SELECT * FROM teilnehmer;"
```

**Das solltest du sehen:**

```
 id | name
----+-------
  1 | Alice
  2 | Bob
(2 rows)
```

Ein **komplett neuer Pod**, aber die Daten sind noch da – sie liegen im Volume hinter dem PVC.

**Zum Knobeln:**

- Was passiert mit den Daten bei `kubectl delete -f k8s/datenbank/`? Welches Objekt in den Dateien ist dafür verantwortlich?
- Warum wäre `replicas: 3` bei der Datenbank keine gute Idee?
- Ändere das Passwort im Secret und wende es an. Kannst du dich danach mit dem neuen Passwort anmelden? Warum (nicht)? Denk an die entsprechende Knobelaufgabe aus Kapitel 06.
- Das Volume liegt bei k3d auf der Festplatte **eines** Nodes. Was passiert mit dem Datenbank-Pod, wenn genau dieser Node ausfällt (Zusatzaufgabe 3)? Wie lösen Cloud-Anbieter das?

---

## Befehlsübersicht

| Befehl                                         | Was passiert?                                                |
| ---------------------------------------------- | ------------------------------------------------------------ |
| `k3d cluster create <name> --agents 2 -p "…"`  | Neues Cluster erstellen                                      |
| `k3d cluster list`                             | Alle k3d-Cluster anzeigen                                    |
| `k3d cluster stop <name>` / `start <name>`     | Cluster anhalten / wieder starten (alles bleibt erhalten)    |
| `k3d cluster delete <name>`                    | Cluster **mit allem darin** löschen                          |
| `k3d image import <image> -c <name>`           | Lokales Image in das Cluster laden                           |
| `k3d node stop <node>` / `start <node>`        | Einen einzelnen Node anhalten / wieder starten               |
| `kubectl get nodes`                            | Nodes anzeigen                                               |
| `kubectl get pods` (`-o wide`, `-A`, `-w`)     | Pods anzeigen (mit IP/Node, alle Namespaces, live)           |
| `kubectl get all`                              | Pods, Services, Deployments und ReplicaSets auf einmal       |
| `kubectl get deployments,services,ingress,pvc` | Mehrere Arten gleichzeitig anzeigen                          |
| `kubectl describe pod <name>`                  | Details und **Events** – erste Anlaufstelle bei Problemen    |
| `kubectl describe service <name>`              | Details eines Service, u. a. die `Endpoints` (Pod-IPs)       |
| `kubectl logs <pod>` (`-f`, `-l app=…`)        | Logs anzeigen (live, für alle Pods mit einem Label)          |
| `kubectl exec -it <pod> -- sh`                 | Shell in einem Pod öffnen                                    |
| `kubectl port-forward <pod> 8081:80`           | Testweise einen Tunnel von `localhost:8081` zum Pod aufbauen |
| `kubectl apply -f <Datei oder Ordner>`         | Manifest anwenden (erstellen **oder** ändern)                |
| `kubectl delete -f <Datei oder Ordner>`        | Alles löschen, was in den Manifesten steht                   |
| `kubectl delete pod <name>`                    | Einen Pod löschen                                            |
| `kubectl rollout status deployment/<name>`     | Fortschritt eines Updates verfolgen                          |
| `kubectl rollout undo deployment/<name>`       | Zur vorherigen Version zurück                                |
| `kubectl rollout restart deployment/<name>`    | Alle Pods eines Deployments nacheinander neu starten         |
| `kubectl config get-contexts`                  | Bekannte Cluster anzeigen (`*` = aktiv)                      |
| `kubectl config use-context <name>`            | Auf ein anderes Cluster wechseln                             |

## Aufräumen

### Einzelne Anwendungen entfernen

```bash
kubectl delete -f k8s/datenbank/
kubectl delete -f k8s/configmap/
kubectl delete -f k8s/apache/
kubectl delete -f k8s/webseite/
```

Ordner, die du nicht angelegt hast, lässt du einfach weg. Danach meldet `kubectl get pods` wieder `No resources found in default namespace.`

### Das Cluster anhalten (später weitermachen)

```bash
k3d cluster stop kurs
```

Alle Deployments, Services und Daten bleiben erhalten. Weiter geht es mit:

```bash
k3d cluster start kurs
kubectl get nodes
```

Nach dem Start dauert es bis zu einer Minute, bis alle Nodes wieder `Ready` sind und die Webseite unter http://localhost:8080 antwortet.

### Das Cluster komplett löschen

```bash
k3d cluster delete kurs
```

Mit `docker ps` siehst du: Alle Container des Clusters sind weg.

### Das Cluster neu aufbauen

Ein großer Vorteil von Manifesten: Dein gesamtes Setup steckt in Dateien. Ein gelöschtes (oder kaputtes) Cluster ist in einer Minute wieder da:

```bash
cd ~/k8s-kurs
k3d cluster create kurs --agents 2 -p "8080:80@loadbalancer"
k3d image import meine-webseite:1.0 -c kurs
kubectl apply -f k8s/webseite/
```

## Fehlerbehebung

| Fehlermeldung / Problem                                                  | Mögliche Ursache und Lösung                                                                                                                                                         |
| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `The connection to the server localhost:8080 was refused`                | `kubectl` kennt kein Cluster → läuft das Cluster (`k3d cluster list`)? Ggf. `k3d cluster start kurs` oder `k3d kubeconfig merge kurs --kubeconfig-switch-context`                   |
| `Cluster creation FAILED, all changes have been rolled back!` (davor eine Zeile mit `port is already allocated`) | Port 8080 ist belegt, z. B. durch einen Container aus Kapitel 06 → `docker ps`, den Container stoppen und `k3d cluster create …` erneut ausführen |
| `Failed to create cluster 'kurs' because a cluster with that name already exists` | Es gibt schon ein Cluster mit dem Namen → weiterverwenden (`k3d cluster start kurs`) oder mit `k3d cluster delete kurs` löschen                                              |
| `Cannot connect to the Docker daemon` bei `k3d cluster create`           | Docker läuft nicht → `sudo systemctl start docker`, siehe Fehlerbehebung in Kapitel 06                                                                                              |
| Pod-Status `ErrImagePull` / `ImagePullBackOff`                           | Image nicht gefunden → Tippfehler im Namen/Tag? `k3d image import` vergessen? Details mit `kubectl describe pod <name>`                                                             |
| Pod-Status `Pending`                                                     | Kein Node hat genug freie Ressourcen, oder das Volume ist nicht verfügbar → `kubectl describe pod <name>` unter Events lesen                                                        |
| Pod-Status `CrashLoopBackOff`                                            | Der Container startet und stürzt sofort wieder ab → `kubectl logs <pod>` (bei Postgres z. B. fehlendes `POSTGRES_PASSWORD`)                                                         |
| Pod-Status `CreateContainerConfigError`                                  | Ein Secret oder eine ConfigMap, auf die der Pod verweist, existiert nicht → Name prüfen, den ganzen Ordner anwenden (`kubectl apply -f k8s/datenbank/`)                             |
| `404 page not found` im Browser                                          | Traefik antwortet, kennt aber keine passende Regel → `kubectl get ingress`: Ingress vorhanden? Hostname richtig geschrieben?                                                        |
| `Bad Gateway` oder `Service Unavailable` im Browser                      | Der Ingress findet keine laufenden Pods → `kubectl get pods`; bei `kubectl describe service <name>` darf `Endpoints` nicht leer sein                                                |
| `Endpoints:` ist bei `kubectl describe service` leer (`<none>`)          | Das Label im `selector` des Service passt nicht zu den Labels der Pods → Schreibweise vergleichen (`kubectl get pods --show-labels`)                                                |
| Browser lädt endlos / `Connection refused` direkt nach `cluster create`  | Traefik startet noch → `kubectl get pods -n kube-system`, warten bis `traefik-…` auf `1/1` steht                                                                                    |
| `error: error parsing ...: yaml: line 12: did not find expected key`     | Einrückung falsch oder Tabs statt Leerzeichen → die genannte Zeile prüfen, in VS Code unten rechts auf „Spaces: 2“ stellen                                                          |
| `selector does not match template labels`                                | Im Deployment stimmen `spec.selector.matchLabels` und `spec.template.metadata.labels` nicht überein                                                                                 |
| `must be less than or equal to memory limit`                             | `requests` ist größer als `limits` → `limits` mindestens so groß wählen wie `requests`                                                                                              |
| `field is immutable` beim `apply`                                        | Manche Felder (z. B. der `selector`) lassen sich nachträglich nicht ändern → Objekt mit `kubectl delete -f` löschen und neu anwenden                                                |
| `error: the path "k8s/webseite/" does not exist`                         | Du bist im falschen Ordner → `cd ~/k8s-kurs` (prüfen mit `pwd` und `ls`)                                                                                                            |
| Browser zeigt nach dem Update noch die alte Version                      | Datei nicht gespeichert, Rollout noch nicht fertig (`kubectl rollout status …`) oder Browser-Cache → `Strg + F5`                                                                    |
| `apache.localhost` / `hallo.localhost` wird nicht gefunden               | Der Browser löst `*.localhost` nicht auf → mit `curl -H "Host: apache.localhost" http://localhost:8080` testen oder Chrome, Edge bzw. Firefox verwenden                             |
| Nach einem Neustart des Laptops / `wsl --shutdown` geht nichts mehr      | Das Cluster ist angehalten → `k3d cluster start kurs` und etwa eine Minute warten                                                                                                   |
| Nach `k3d cluster start` bleiben die Agents dauerhaft auf `NotReady`     | Tritt bei **älteren k3d-Versionen** (vor 5.9) auf → k3d aktualisieren (Aufgabe 1, Schritt 2) und das Cluster neu aufbauen (siehe [Aufräumen](#das-cluster-neu-aufbauen))            |
| `kubectl logs -l … -f` meldet `exceeding max allowed concurrent logs`    | Mehr als 5 Pods passen auf das Label → `--max-log-requests 10` anhängen                                                                                                             |
| Alles ist sehr langsam, Pods bleiben auf `Pending` oder starten ständig neu | Zu wenig Arbeitsspeicher → andere Programme schließen; unter Windows siehe [K3D-WINDOWS.md](./K3D-WINDOWS.md), Abschnitt Arbeitsspeicher                                          |

## Kontrollfragen

- Welche Probleme löst ein **Orchestrator**, die du mit `docker run` allein nicht lösen kannst?
- Was bedeutet **Wunschzustand** (_desired state_), und was macht Kubernetes, wenn der Ist-Zustand davon abweicht?
- Was ist der Unterschied zwischen **k3s**, **k3d** und **Kubernetes**?
- Woraus bestehen die **Nodes** deines k3d-Clusters tatsächlich?
- Was ist der Unterschied zwischen einem **Pod** und einem **Deployment**?
- Warum bleibt ein mit `kubectl run` gestarteter Pod nach dem Löschen weg, ein Pod aus einem Deployment aber nicht?
- Warum braucht man einen **Service**, obwohl jeder Pod schon eine eigene IP-Adresse hat?
- Woran erkennt ein Service, an welche Pods er Anfragen weiterleiten soll?
- Wofür ist der **Ingress** da, und warum reicht das Ingress-Manifest allein nicht aus?
- Welchen Weg nimmt eine Anfrage von `http://localhost:8080` bis zu deinem Container?
- Warum musstest du dein Image mit `k3d image import` in das Cluster laden? Wie läuft das in einem echten Cluster?
- Was passiert bei einem **Rolling Update** Schritt für Schritt, und warum ist die Seite dabei durchgehend erreichbar?
- Was passiert mit den laufenden Pods, wenn du ein Image einträgst, das es nicht gibt?
- Warum solltest du lieber die YAML-Datei ändern und `kubectl apply` ausführen, statt `kubectl scale` oder `kubectl rollout undo` zu verwenden?
- Was ist der Unterschied zwischen `requests` und `limits`?
- Wofür verwendet man eine **ConfigMap**, wofür ein **Secret**? Ist ein Secret verschlüsselt?
- Was entspricht in Kubernetes dem **Named Volume** aus Docker Compose?
- Wie lange wartet Kubernetes ungefähr, bevor es die Pods eines ausgefallenen Nodes ersetzt – und warum nicht sofort?
- Mit welchem Befehl findest du heraus, **warum** ein Pod nicht startet?
