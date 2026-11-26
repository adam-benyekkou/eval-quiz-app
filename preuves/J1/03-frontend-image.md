# Preuves J1 — Section 3 : image frontend (Dockerfile racine)

## A. Build multi-étapes

```bash
$ docker build -t quiz-frontend:local .
#14 3.269 dist/assets/main-28d2d5a1.js                    8.78 kB
#14 3.269 dist/assets/questions_ansible-88f6e1dc.js       13.33 kB
#14 3.272 ✓ built in 951ms
#15 [stage-1 3/3] COPY --from=build /app/dist /usr/share/nginx/html
# exit 0

$ docker images quiz-frontend:local --format '{{.Repository}}:{{.Tag}} {{.Size}}'
quiz-frontend:local 92.4MB
```

Deux pages d'entrée compilées (`index.html`, `gestion-quiz.html` via `vite.config.js`).

## B. Conteneur autonome — routes statiques

Backend factice non démarré : seules les routes statiques sont testées.

```bash
$ docker run --rm -d --name j1-frontend-test -p 8087:8080 \
    -e BACKEND_HOST=127.0.0.1 -e BACKEND_PORT=3007 quiz-frontend:local
$ for u in / /gestion-quiz /admin.js /health; do curl -s -o /dev/null -w "$u -> %{http_code}\n" localhost:8087$u; done
/ -> 200
/gestion-quiz -> 200
/admin.js -> 200
/health -> 502        # backend absent : normal

$ docker exec j1-frontend-test id
uid=101(nginx) gid=101(nginx) groups=101(nginx)   # non-root
```

## C. Rendu du template par envsubst

```bash
$ docker exec j1-frontend-test sed -n '6,9p' /etc/nginx/conf.d/default.conf
upstream backend {
    least_conn;
    server 127.0.0.1:3007;
}
```

Le `20-envsubst-on-templates.sh` du entrypoint a rendu
`nginx/default.conf.template` avec `BACKEND_HOST` / `BACKEND_PORT`.

```text
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/default.conf.template to /etc/nginx/conf.d/default.conf
```

## D. Comportement si l'upstream n'est pas résolvable (hypothèse J4)

```bash
$ docker run --rm -e BACKEND_HOST=backend -e BACKEND_PORT=3007 quiz-frontend:local
2026/11/26 10:29:47 [emerg] 1#1: host not found in upstream "backend:3007" in /etc/nginx/conf.d/default.conf:9
$ echo $?
1
```

Nginx **refuse de démarrer** si le nom d'upstream ne résout pas. Conséquence Compose :
`depends_on: backend` suffit (le nom `backend` est résolu par le DNS de Compose dès la
création du conteneur) ; en J4, le FQDN de l'app Container Apps devra être fourni et
résolvable au démarrage.

## E. Hadolint

```bash
$ docker run --rm -i hadolint/hadolint < Dockerfile
# (aucune sortie)
# exit 0
```

## G. Trivy — `DS-0002` corrigé

Premier passage CI (workflow `trivy.yml`, `scanners: vuln,secret,misconfig`) :

```text
│ Dockerfile │ dockerfile │ - │ - │ 1 │
DS-0002 (HIGH): Specify at least 1 USER command in Dockerfile with non-root user as argument
```

L'image `nginxinc/nginx-unprivileged` tourne déjà en uid 101, mais le contrôle statique
exige l'instruction. Ajout de `USER 101:101` en fin d'étape finale.

```bash
$ docker run --rm -v "$PWD":/src aquasec/trivy:latest config --severity HIGH,CRITICAL --quiet /src
│ Dockerfile         │ dockerfile │ 0 │
│ backend/Dockerfile │ dockerfile │ 0 │
# exit 0

$ docker run -d -e BACKEND_HOST=127.0.0.1 -e BACKEND_PORT=3007 quiz-frontend:local
$ curl -o /dev/null -w '%{http_code}\n' localhost:8088/ localhost:8088/gestion-quiz
200
200
$ docker exec <conteneur> id
uid=101(nginx) gid=101(nginx) groups=101(nginx)
```

Le conteneur démarre et sert les pages avec le `USER` explicite : aucune régression.

## F. Changement de fichier

`nginx/nginx.conf` → `nginx/default.conf.template` (`git mv`), seules différences :
`listen 8080` et `${BACKEND_HOST}:${BACKEND_PORT}`. Routes `/`, `/gestion-quiz`, `/api/`,
`/health` conservées. `database/nginx/nginx.conf` reste intact (doublon documenté en §7
de `docs/architecture-locale.md`).
