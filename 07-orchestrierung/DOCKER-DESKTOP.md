# Kubernetes mit Docker Desktop – Schritt für Schritt

**Docker Desktop** bringt ein eigenes Kubernetes mit, das du mit wenigen Klicks einschaltest. Du brauchst dann **kein k3d** – `kubectl` wird gleich mitgeliefert.

Diese Anleitung ist eine **Alternative** zu den Aufgaben 1 und 2 im [Haupt-Readme](./Readme.md). Du richtest das Cluster ein (Schritte 1–3), testest es (Schritt 4), bringst deine Webseite zum Laufen (Schritte 5–6) und erfährst, was beim Weiterarbeiten im Haupt-Readme anders ist (Schritt 7).

## k3d oder Docker Desktop?

|                              | **k3d** (Haupt-Readme)                           | **Docker Desktop**                                            |
| ---------------------------- | ------------------------------------------------ | ------------------------------------------------------------- |
| Installation                 | `kubectl` und `k3d` im Terminal installieren     | Ein paar Klicks in der Oberfläche                             |
| Braucht                      | Irgendein Docker (auch Docker Engine in der WSL) | **Docker Desktop**                                            |
| Mehrere Nodes                | Ja (`--agents 2`)                                | Nur beim Cluster-Typ **kind**                                 |
| Mehrere Cluster gleichzeitig | Ja                                               | Nein, genau eines                                             |
| Ingress-Controller           | **Traefik** ist dabei                            | Keiner – dafür `LoadBalancer`-Services direkt auf `localhost` |
| Lokale Images                | `k3d image import`                               | Je nach Einstellung direkt verfügbar (siehe Schritt 5)        |
| Cluster löschen und neu      | Sekunden (`k3d cluster delete`)                  | **Reset cluster** in der Oberfläche                           |
| Name des kubectl-Kontexts    | `k3d-kurs`                                       | `docker-desktop`                                              |

## Voraussetzungen

- **Windows 10/11** oder **macOS** (für Linux gibt es Docker Desktop ebenfalls, dort ist k3d aber der einfachere Weg)
- Mindestens **8 GB Arbeitsspeicher**
- Unter Windows: **WSL 2** ist installiert (siehe Kapitel 01)
- **Port 8080** ist frei (kein laufendes k3d-Cluster, kein Container aus Kapitel 06 auf diesem Port)

> **Achtung, wenn du Kapitel 06 gemacht hast:** Dort hast du **Docker Engine direkt in deiner WSL** installiert, und dort stand: _Nicht beides gleichzeitig verwenden!_ Das gilt weiterhin. Docker Desktop bringt einen **eigenen, zweiten** Docker mit. Damit sich beide nicht in die Quere kommen:
>
> - Führe die Befehle dieser Anleitung unter Windows in der **PowerShell** aus, **nicht** im Ubuntu-Terminal
> - Lass in Docker Desktop unter **Settings → Resources → WSL integration** den Schalter für deine Ubuntu-Distribution **aus**
>
> Images, die du in der WSL gebaut hast, sieht Docker Desktop **nicht** (und umgekehrt) – es sind zwei getrennte Docker-Installationen.

> **Lizenz:** Docker Desktop ist für die private Nutzung, für Ausbildung und für kleine Firmen kostenlos. Größere Unternehmen brauchen ein kostenpflichtiges Abo.

Alle Befehle gibst du unter Windows in der **PowerShell** und unter macOS im **Terminal** ein.

---

## Schritt 1: Docker Desktop installieren

Hast du Docker Desktop schon, weiter mit Schritt 2.

1. [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) öffnen und den Installer für dein System herunterladen (Windows: _AMD64_, außer du hast einen ARM-Laptop; Mac: _Apple Silicon_ oder _Intel_)
2. Installer ausführen
   - **Windows:** Die Option **Use WSL 2 instead of Hyper-V** angehakt lassen. Nach der Installation ab- und wieder anmelden bzw. neu starten, wenn der Installer das verlangt
   - **macOS:** Das Docker-Symbol in den Ordner **Applications** ziehen
3. **Docker Desktop** starten und die Nutzungsbedingungen akzeptieren. Die Anmeldung mit einem Docker-Account kannst du überspringen
4. Warten, bis unten links in der Statusleiste **Engine running** steht

Prüfen:

```bash
docker run hello-world
```

**Das solltest du sehen:** unter anderem die Zeile `Hello from Docker!`.

## Schritt 2: Kubernetes einschalten

Die Oberfläche von Docker Desktop hat sich über die Versionen verändert. Nimm den Weg, den deine Version anbietet:

**Aktuelle Versionen:**

1. Im Docker-Desktop-Fenster links in der Seitenleiste auf **Kubernetes** klicken
2. Auf **Create cluster** klicken
3. Den **Cluster-Typ** wählen (siehe Tabelle unten)
4. Auf **Create** klicken

**Ältere Versionen:**

1. Oben rechts auf das **Zahnrad** (**Settings**) klicken, dann links **Kubernetes**
2. Den Schalter **Enable Kubernetes** einschalten
3. Den **Cluster-Typ** wählen (falls angeboten)
4. Auf **Apply & restart** klicken und mit **Install** bestätigen

| Cluster-Typ | Was du bekommst                                                    | Empfehlung                                               |
| ----------- | ------------------------------------------------------------------ | -------------------------------------------------------- |
| **kubeadm** | Ein Cluster mit **einem** Node                                     | **Für den Einstieg** – am einfachsten                    |
| **kind**    | Ein Cluster mit **mehreren** Nodes (Anzahl und Version einstellbar) | Wenn du sehen willst, wie Pods auf Nodes verteilt werden |

Jetzt lädt Docker Desktop die Kubernetes-Images herunter. Das dauert beim ersten Mal **einige Minuten**.

**Das solltest du sehen:** Sobald alles läuft, erscheint unten links in der Statusleiste neben dem Docker-Status auch **Kubernetes running** (grünes Symbol).

> **Tipp:** Die Option **Show system containers (advanced)** kannst du aus lassen. Sonst tauchen alle Kubernetes-internen Container bei `docker ps` auf.

## Schritt 3: kubectl prüfen und das Cluster ansehen

Docker Desktop installiert `kubectl` gleich mit. Öffne ein **neues** Terminal (damit es das Programm findet):

```bash
kubectl version
```

**Das solltest du sehen** (Versionsnummern können abweichen):

```
Client Version: v1.34.1
Kustomize Version: v5.7.1
Server Version: v1.34.3
```

Steht dort eine **Server Version**, erreicht `kubectl` das Cluster.

`kubectl` merkt sich Cluster als **Kontexte**. Docker Desktop hat den Kontext `docker-desktop` angelegt:

```bash
kubectl config get-contexts
```

```
CURRENT   NAME             CLUSTER          AUTHINFO
*         docker-desktop   docker-desktop   docker-desktop
```

Steht der Stern `*` nicht bei `docker-desktop` (z. B. weil du auch ein k3d-Cluster hast), wechsle:

```bash
kubectl config use-context docker-desktop
```

Jetzt die Nodes ansehen:

```bash
kubectl get nodes
```

**Das solltest du sehen** – beim Typ **kubeadm**:

```
NAME             STATUS   ROLES           AGE   VERSION
docker-desktop   Ready    control-plane   2m    v1.34.3
```

Beim Typ **kind** (hier mit 2 Nodes):

```
NAME                    STATUS   ROLES           AGE   VERSION
desktop-control-plane   Ready    control-plane   2m    v1.34.3
desktop-worker          Ready    <none>          2m    v1.34.3
```

Und was Kubernetes selbst zum Laufen braucht:

```bash
kubectl get pods -A
```

Du siehst eine Liste von Pods im Namespace `kube-system` (z. B. `coredns-…`, `etcd-…`, `kube-apiserver-…`), alle mit dem Status `Running`.

## Schritt 4: Der erste Pod

```bash
kubectl run mein-nginx --image=nginx
kubectl get pods
```

**Das solltest du sehen:**

```
pod/mein-nginx created
NAME         READY   STATUS              RESTARTS   AGE
mein-nginx   0/1     ContainerCreating   0          2s
```

Wiederhole `kubectl get pods`, bis dort `Running` und `1/1` steht. Dann einen Tunnel zum Pod aufbauen:

```bash
kubectl port-forward pod/mein-nginx 8081:80
```

```
Forwarding from 127.0.0.1:8081 -> 80
Forwarding from [::1]:8081 -> 80
```

Der Befehl bleibt stehen – der Tunnel ist offen. **http://localhost:8081** zeigt **„Welcome to nginx!“**.

Mit `Strg + C` beenden und aufräumen:

```bash
kubectl delete pod mein-nginx
```

**Dein Cluster funktioniert.** Was die Befehle im Einzelnen bedeuten, steht im Haupt-Readme in **Aufgabe 3**.

## Schritt 5: Deine eigene Webseite als Deployment

### Die Dateien

Du brauchst einen Ordner mit `Dockerfile`, `index.html` und den Manifesten im Unterordner `k8s/`. Am einfachsten nimmst du die Musterlösung aus dem Ordner [`beispiel/`](./beispiel/) dieses Kapitels.

> **Windows:** Dein Kurs-Repository liegt vermutlich in der WSL. Klone es für diese Anleitung zusätzlich unter Windows (in der PowerShell mit `git clone <Adresse>`) oder lade es auf GitHub über **Code → Download ZIP** herunter und entpacke es.

Wechsle im Terminal in den Ordner:

```bash
cd 07-orchestrierung/beispiel
ls
```

**Das solltest du sehen:** `Dockerfile`, `index.html` und den Ordner `k8s`.

### Das Image bereitstellen

Das Cluster braucht das Image `meine-webseite:1.0`. Welcher Weg funktioniert, hängt von deinem Cluster-Typ ab:

| Cluster-Typ | Lokal gebautes Image (`docker build`)                                                                                                                                                                 |
| ----------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **kubeadm** | **Direkt verwendbar** – der Node benutzt denselben Image-Speicher wie `docker`                                                                                                                         |
| **kind**    | Nur verwendbar, wenn in Docker Desktop der **containerd image store** aktiv ist (**Settings → General → Use containerd for pulling and storing images**). Sonst endet der Pod mit `ErrImagePull`       |

**Weg A – lokal bauen** (kubeadm, oder kind mit containerd image store):

```bash
docker build -t meine-webseite:1.0 .
```

**Weg B – von Docker Hub** (funktioniert **immer**): Du verwendest das Image, das du in Kapitel 06, Aufgabe 4, hochgeladen hast. Öffne `k8s/webseite/deployment.yaml` und ändere die Zeile `image:` auf den vollen Namen:

```yaml
image: <dein-username>/meine-webseite:1.0
```

Ein `docker login` ist nicht nötig, weil das Repository öffentlich ist. (Das Image aus Kapitel 06 zeigt den Text „Hallo aus dem Container!“ – für diese Übung ist das egal.)

### Das Deployment anwenden

```bash
kubectl apply -f k8s/webseite/deployment.yaml
kubectl get pods -o wide
```

**Das solltest du sehen** (nach einigen Sekunden):

```
deployment.apps/webseite created

NAME                        READY   STATUS    RESTARTS   AGE   IP            NODE
webseite-7fd5f445b6-9ms7g   1/1     Running   0          10s   10.244.1.9    desktop-worker
webseite-7fd5f445b6-9s7sn   1/1     Running   0          10s   10.244.1.11   desktop-worker
webseite-7fd5f445b6-9xkrb   1/1     Running   0          10s   10.244.1.10   desktop-worker
```

Drei Pods mit `Running`. (Beim Typ **kubeadm** steht unter `NODE` überall `docker-desktop`.)

> **Steht dort `ErrImagePull` oder `ImagePullBackOff`?** Dann findet das Cluster dein lokales Image nicht. Nimm **Weg B**: Image-Namen in der Datei ändern, speichern und `kubectl apply -f k8s/webseite/deployment.yaml` erneut ausführen. Die fehlerhaften Pods werden automatisch ersetzt.

## Schritt 6: Die Webseite erreichbar machen

Im Haupt-Readme geschieht das über einen **Ingress**. Docker Desktop hat **keinen Ingress-Controller** – ein Ingress-Manifest wird zwar angenommen, aber niemand setzt es um.

Dafür kann Docker Desktop etwas anderes: Jeder Service vom Typ **`LoadBalancer`** ist automatisch unter `localhost` erreichbar. Die Datei [`k8s/docker-desktop/webseite-loadbalancer.yaml`](./beispiel/k8s/docker-desktop/webseite-loadbalancer.yaml) liegt in der Musterlösung schon bereit:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: webseite-lb
spec:
  type: LoadBalancer
  selector:
    app: webseite
  ports:
    - port: 8080 # http://localhost:8080 auf deinem Rechner
      targetPort: 80 # Port im Container
```

```bash
kubectl apply -f k8s/docker-desktop/webseite-loadbalancer.yaml
kubectl get services
```

**Das solltest du sehen:**

```
service/webseite-lb created

NAME          TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes    ClusterIP      10.96.0.1       <none>        443/TCP          20m
webseite-lb   LoadBalancer   10.96.208.196   172.19.0.6    8080:31002/TCP   5s
```

Unter `EXTERNAL-IP` steht je nach Cluster-Typ `localhost` oder eine IP-Adresse wie `172.19.0.6`. In beiden Fällen gilt: Öffne **http://localhost:8080** – du siehst deine Webseite, ausgeliefert von drei Pods 🎉

> Steht unter `EXTERNAL-IP` dauerhaft `<pending>` oder lädt die Seite nicht, ist meist Port 8080 auf deinem Rechner schon belegt. Ändere in der Datei `port: 8080` z. B. in `port: 9080`, wende sie erneut an und öffne `http://localhost:9080`.

> **Service-Typen im Überblick:**
>
> | Typ            | Erreichbar von                                                                                                                                                     |
> | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
> | `ClusterIP`    | Nur **innerhalb** des Clusters (Standard, wenn `type` fehlt)                                                                                                       |
> | `NodePort`     | Zusätzlich über einen Port (30000–32767) auf jedem Node                                                                                                            |
> | `LoadBalancer` | Zusätzlich über eine Adresse **außerhalb** des Clusters. In der Cloud entsteht dafür ein echter Loadbalancer (kostet Geld!), bei Docker Desktop ist es `localhost` |

## Schritt 7: Weiter im Haupt-Readme – was ist anders?

Ab hier kannst du mit dem [Haupt-Readme](./Readme.md) weitermachen. Die Befehle sind dieselben, mit diesen Ausnahmen:

| Im Haupt-Readme                                      | Mit Docker Desktop                                                                                                             |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| **Aufgabe 1 + 2** (Installation, Cluster erstellen)  | Entfallen – das hast du mit den Schritten 1–3 hier erledigt                                                                    |
| **Aufgabe 3** (erster Pod, kubectl-Befehle)          | **Unverändert**                                                                                                                |
| **Aufgabe 4** (Deployment, Selbstheilung, Skalieren) | **Unverändert**, bis auf den Image-Import                                                                                      |
| `k3d image import meine-webseite:… -c kurs`          | Entfällt. Weg A: nur `docker build`. Weg B: Image zu Docker Hub pushen und den vollen Namen im Manifest verwenden              |
| **Aufgabe 5:** Ingress, `http://localhost:8080`      | Statt des Ingress den `LoadBalancer`-Service aus Schritt 6. `service.yaml` kannst du anwenden, `ingress.yaml` bewirkt nichts   |
| **Aufgabe 6** (Rolling Update, Rollback)             | **Unverändert**, bis auf den Image-Import                                                                                      |
| `http://apache.localhost:8080` usw. (Zusatzaufgaben) | Ohne Ingress-Controller nicht erreichbar → stattdessen einen Tunnel öffnen, siehe unten                                        |
| Zusatzaufgabe 3 (`k3d node stop …`)                  | Nicht möglich                                                                                                                  |
| `k3d cluster stop / start / delete`                  | Docker Desktop beenden / starten bzw. **Reset cluster** (Schritt 8)                                                            |

### Zusatzaufgaben ohne Ingress

Die Manifeste der Zusatzaufgaben (Apache, ConfigMap, Datenbank) kannst du unverändert anwenden. Die Ingress-Objekte darin werden angelegt, bleiben aber wirkungslos – bei `kubectl get ingress` ist die Spalte `ADDRESS` leer.

Du erreichst die Anwendungen stattdessen über `port-forward`, diesmal auf einen **Service** statt auf einen Pod. Jeder Befehl braucht ein **eigenes Terminal** und bleibt stehen, solange der Tunnel offen ist:

```bash
kubectl port-forward service/apache 8081:80     # http://localhost:8081  →  „It works!“
kubectl port-forward service/hallo 8082:80      # http://localhost:8082  →  „Hallo aus einer ConfigMap!“
kubectl port-forward service/adminer 8083:80    # http://localhost:8083  →  Adminer-Anmeldeseite
```

> **Für Fortgeschrittene:** Du kannst auch selbst einen Ingress-Controller installieren, dann funktionieren die Ingress-Manifeste. Die Anleitung für Docker Desktop steht in der Dokumentation von [ingress-nginx](https://kubernetes.github.io/ingress-nginx/deploy/). Für diesen Kurs ist das nicht nötig.

### PowerShell-Besonderheiten (Windows)

Die `kubectl`-Befehle sind in der PowerShell identisch. Bei ein paar Linux-Befehlen aus dem Haupt-Readme musst du umdenken:

| Im Haupt-Readme (Bash)             | In der PowerShell                                                      |
| ---------------------------------- | ---------------------------------------------------------------------- |
| `curl -s http://localhost:8080`    | `curl.exe -s http://localhost:8080` (mit **.exe**!)                    |
| `mkdir -p ~/k8s-kurs/k8s/webseite` | `mkdir ~\k8s-kurs\k8s\webseite`                                        |
| `for i in 1 2 3 4 5 6; do …; done` | `1..6 \| ForEach-Object { curl.exe -s http://localhost:8080 > $null }` |
| `… \| base64 -d`                   | siehe [K3D-WINDOWS.md](./K3D-WINDOWS.md)                               |

## Schritt 8: Aufräumen, zurücksetzen, ausschalten

**Einzelne Anwendungen entfernen:**

```bash
kubectl delete -f k8s/docker-desktop/
kubectl delete -f k8s/webseite/
```

**Das solltest du sehen:** je eine Zeile mit `deleted`, danach meldet `kubectl get pods`: `No resources found in default namespace.`

**Das ganze Cluster auf Anfang setzen** (löscht **alles**, was du darin angelegt hast): in der Ansicht **Kubernetes** auf **Reset cluster** – in älteren Versionen **Settings → Kubernetes → Reset Kubernetes Cluster**.

**Kubernetes wieder ausschalten** (spart Arbeitsspeicher und Akku, solange du es nicht brauchst): in der Ansicht **Kubernetes** auf **Stop** – in älteren Versionen **Settings → Kubernetes →** Schalter **Enable Kubernetes** aus → **Apply & restart**.

## Zwischen k3d und Docker Desktop wechseln

Du kannst beides nebeneinander haben. `kubectl` spricht immer mit dem Cluster des **aktiven Kontexts**:

```bash
kubectl config get-contexts                  # alle anzeigen, * = aktiv
kubectl config use-context docker-desktop    # Docker Desktop
kubectl config use-context k3d-kurs          # k3d
```

> **Vor jedem `kubectl apply` oder `kubectl delete` kurz prüfen, wo du bist** – mit `kubectl config current-context`. Im Beruf ist „im falschen Cluster gelöscht“ ein Klassiker.

Achtung bei den Ports: Ein k3d-Cluster mit `-p "8080:80@loadbalancer"` und ein `LoadBalancer`-Service auf Port 8080 in Docker Desktop wollen **denselben Port** auf deinem Rechner. Stoppe eines von beiden (`k3d cluster stop kurs`) oder wähle einen anderen Port.

## Fehlerbehebung

| Problem                                                                                 | Mögliche Ursache und Lösung                                                                                                                                                         |
| --------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Kubernetes bleibt minutenlang auf **Starting**                                          | Beim ersten Start werden viele Images geladen – Geduld. Dauert es länger als 10 Minuten: Docker Desktop beenden und neu starten, sonst **Reset cluster**                            |
| `kubectl` wird nicht gefunden                                                           | Terminal nach dem Einschalten von Kubernetes neu öffnen. Unter Windows liegt es in `C:\Program Files\Docker\Docker\resources\bin`, unter macOS in `/usr/local/bin`                  |
| `The connection to the server localhost:8080 was refused`                               | Kein Kontext aktiv oder Kubernetes nicht eingeschaltet → Schritt 2 prüfen, dann `kubectl config use-context docker-desktop`                                                         |
| `Unable to connect to the server: dial tcp 127.0.0.1:6443: connect: connection refused` | Docker Desktop läuft nicht oder Kubernetes startet noch → Statusleiste unten links prüfen                                                                                           |
| `kubectl config get-contexts` zeigt keinen Kontext `docker-desktop`                     | Du bist im Ubuntu-Terminal der WSL statt in der PowerShell, oder Kubernetes ist nicht eingeschaltet                                                                                 |
| `kubectl get nodes` zeigt die Nodes eines **anderen** Clusters                          | Falscher Kontext → `kubectl config use-context docker-desktop`                                                                                                                      |
| Pod-Status `ErrImagePull` / `ImagePullBackOff` bei `meine-webseite:1.0`                 | Das Cluster findet das lokale Image nicht (Typ **kind** ohne containerd image store) → Image von Docker Hub verwenden, siehe Schritt 5, Weg B                                       |
| `http://localhost:8080` lädt nicht                                                      | Pods nicht `Running` (`kubectl get pods`), Service nicht angewendet (`kubectl get services`), oder der Port ist schon belegt (z. B. durch ein k3d-Cluster)                          |
| Bei `kubectl get services` steht unter `EXTERNAL-IP` dauerhaft `<pending>`              | Meist ist der Port auf deinem Rechner schon belegt → anderen `port` wählen und erneut `apply`                                                                                       |
| Ingress angelegt, aber `http://apache.localhost:8080` zeigt nichts                      | Docker Desktop hat keinen Ingress-Controller → `kubectl port-forward service/apache 8081:80`, siehe Schritt 7                                                                       |
| `error: the path "k8s/webseite/deployment.yaml" does not exist`                         | Du bist im falschen Ordner → in den Ordner `beispiel` wechseln (prüfen mit `ls`)                                                                                                    |
| Im Ubuntu-Terminal (WSL) verhält sich `docker` plötzlich anders                         | Die WSL-Integration von Docker Desktop ist für Ubuntu aktiv und überlagert dein Docker aus Kapitel 06 → **Settings → Resources → WSL integration** ausschalten                      |
| Der Laptop wird langsam, der Lüfter läuft ständig                                       | Kubernetes braucht dauerhaft Arbeitsspeicher und CPU → ausschalten, wenn du es nicht brauchst (Schritt 8)                                                                           |

## Kontrollfragen

- Worin unterscheidet sich das Kubernetes von Docker Desktop von einem k3d-Cluster? Nenne zwei Punkte.
- Was ist ein **Kontext** in `kubectl`, und wie wechselst du ihn?
- Warum bewirkt ein Ingress-Manifest in Docker Desktop zunächst nichts?
- Was ist der Unterschied zwischen den Service-Typen `ClusterIP` und `LoadBalancer`?
- Warum findet das Cluster ein lokal gebautes Image je nach Cluster-Typ nicht – und welcher Weg funktioniert immer?
- Warum solltest du Docker Desktop und Docker Engine in der WSL nicht im selben Terminal mischen?
