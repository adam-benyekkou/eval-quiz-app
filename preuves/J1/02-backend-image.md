# Preuves J1 — Section 2 : image backend

## A. Lock file

`backend/package-lock.json` était **absent** du dépôt : `npm ci` aurait échoué.
Généré une fois avec `npm ci`-compatible :

```bash
$ cd backend && npm install --no-audit --no-fund
added 177 packages in 11s
# exit 0 — package-lock.json créé (75 067 octets), versionné avec cette branche
```

`npm ci --omit=dev` est ensuite employé dans l'image, donc builds reproductibles.

## B. Build

```bash
$ docker build -t quiz-backend:local backend
...
#10 [5/5] COPY server.js ./
#11 exporting to image
#11 naming to docker.io/library/quiz-backend:local 0.0s done
# exit 0
$ docker images quiz-backend:local --format '{{.Repository}}:{{.Tag}} {{.Size}}'
quiz-backend:local 225MB
```

## C. Exécution et santé

Le backend exige `RESEND_API_KEY` au démarrage (voir preuve 01), valeur factice ici.

```bash
$ docker run --rm -d --name j1-backend-test -p 3007:3007 -e RESEND_API_KEY=re_dummy quiz-backend:local
1dfa75d68da8...

$ curl -s -i --max-time 5 localhost:3007/health
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8
{"status":"ok"}

$ docker exec j1-backend-test id
uid=1000(node) gid=1000(node) groups=1000(node)
```

## D. Hadolint

```bash
$ docker run --rm -i hadolint/hadolint < backend/Dockerfile
# (aucune sortie)
# exit 0
```

Premier passage non propre :

```text
-:15 DL3066 info: Non-numeric user-id may not be resolvable by host system
# exit 1
```

Correction : `USER 1000:1000` (uid/gid du compte `node` de l'image officielle), forme
numérique résolvable par l'hôte et les orchestrateurs. Second passage : exit 0.
