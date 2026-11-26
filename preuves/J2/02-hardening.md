# Preuves J2 — Section 2 : durcissement

Branche `feature/j2-hardening`, images `:fixed`. Commandes exécutées depuis la racine du
dépôt.

## A. Choix de la base backend, mesuré

```bash
$ for t in node:20-alpine node:22-alpine node:24-alpine; do
    docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
      aquasec/trivy:latest image --severity CRITICAL,HIGH --format json "$t" | ... | count
  done
node:20-alpine  {'HIGH': 28, 'CRITICAL': 1}  total 29
node:22-alpine  {'HIGH': 10}                 total 10
node:24-alpine  {'HIGH': 6}                  total 6
```

Node 20 étant en fin de vie (avril 2026), la base passe à `node:24-alpine` (LTS).

## B. Builds `:fixed`

```bash
$ docker build -t quiz-backend:fixed backend
# exit 0
$ docker build -t quiz-frontend:fixed .
# exit 0

$ docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep -E 'baseline|fixed'
quiz-backend:baseline  225MB
quiz-backend:fixed     278MB
quiz-frontend:baseline 92.4MB
quiz-frontend:fixed    112MB
```

La croissance vient de `apk upgrade` (anciens fichiers conservés dans la couche de base) et
de `node:24-alpine` ; elle est assumée en échange de la suppression des CVE.

## C. Outils de build retirés de l'image d'exécution backend

```bash
$ docker run --rm quiz-backend:fixed sh -c 'command -v npm || echo "npm absent";
    command -v npx || echo "npx absent"; command -v node; node -v'
npm absent
npx absent
/usr/local/bin/node
v24.22.3

$ docker run --rm quiz-backend:fixed sh -c 'ls /usr/local/lib/node_modules 2>/dev/null || echo "aucun module global"'
aucun module global

$ docker run -d --rm --name j2-backend-test -p 3017:3007 -e RESEND_API_KEY=re_dummy quiz-backend:fixed
$ sleep 2 && curl -s -o /dev/null -w 'health=%{http_code}\n' localhost:3017/health
health=200
$ docker inspect --format '{{.State.Health.Status}}' j2-backend-test
healthy
```

Le shell et `node` restent disponibles (`docker compose exec backend sh` testé en §E).

## D. Scan après durcissement

```bash
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
    aquasec/trivy:latest image --severity CRITICAL,HIGH,MEDIUM \
    --format table quiz-backend:fixed > preuves/J2/trivy-apres-backend.txt
# exit 0 ; idem frontend et JSON
```

| Image | CRITICAL | HIGH | MEDIUM | Total |
| --- | ---: | ---: | ---: | ---: |
| `quiz-backend:fixed` | 0 | 0 | 2 | 2 |
| `quiz-frontend:fixed` | 0 | 0 | 0 | 0 |

Résidu backend, tous deux MEDIUM et transitifs :

```text
CVE-2026-118773 glob       10.5.0 -> 14.0.2  (DoS via traversal incomplète)
CVE-2026-118764 minimatch  9.0.9  -> 11.0.1  (DoS via expansion de motif)
```

Chaîne : `resend@2.1.0 → @react-email/render@0.0.9 → pretty@2.0.0 → js-beautify@1.15.4`.
Correction = montée majeure sans test de rendu email ; documentée en résiduel
(`docs/securite-trivy.md` §4), sans `.trivyignore`.

Base backend après correction : `alpine 3.24.4`, `openssl`, `musl`, `zlib` à jour.
Base frontend : `alpine 3.24.2`, `brotli-libs 1.2.1-r0`, `curl 8.23.0-r0`, `libexpat
2.11.0-r0`, `musl 1.2.6-r3`, `zlib 1.4-r0`.

## E. Configuration et secrets après correction

```bash
$ docker run --rm -v "$PWD":/src aquasec/trivy:latest \
    config --severity CRITICAL,HIGH,MEDIUM,LOW /src > preuves/J2/trivy-config-apres.txt
# exit 0
│ Dockerfile         │ dockerfile │ 0 │
│ backend/Dockerfile │ dockerfile │ 0 │
```

`DS-0026` est corrigé par les `HEALTHCHECK`. Aucun secret détecté (scan inchangé, voir
`01-baseline-scans.md` §F).

## F. Compose : lecture seule, capabilities, parcours J1

`docker-compose.yml` ajoute sur `backend` et `frontend` : `read_only: true`, `tmpfs`,
`cap_drop: [ALL]`, `no-new-privileges:true`. `db` reste inchangé (l'entrypoint PostgreSQL a
besoin d'écrire et de `chown` son volume).

```bash
$ docker compose config -q && echo config-ok
config-ok

$ docker compose up -d --build --force-recreate
 Container eval-quiz-app-db-1 Healthy
 Container eval-quiz-app-backend-1 Started
 Container eval-quiz-app-frontend-1 Started
# exit 0

$ docker compose ps --format '{{.Service}} {{.Status}}'
backend Up 9 seconds (healthy)
db Up 15 seconds (healthy)
frontend Up 9 seconds (healthy)

$ docker inspect eval-quiz-app-backend-1 eval-quiz-app-frontend-1 \
    --format '{{.Name}} read_only={{.HostConfig.ReadonlyRootfs}} capdrop={{.HostConfig.CapDrop}} securityopt={{.HostConfig.SecurityOpt}} user={{.Config.User}} health={{.State.Health.Status}}'
/eval-quiz-app-backend-1 read_only=true capdrop=[ALL] securityopt=[no-new-privileges:true] user=1000:1000 health=healthy
/eval-quiz-app-frontend-1 read_only=true capdrop=[ALL] securityopt=[no-new-privileges:true] user=101:101 health=healthy
```

Sans `tmpfs` propriétaire, le frontend ne démarre pas correctement : `envsubst` (uid 101)
ne peut pas écrire `/etc/nginx/conf.d/default.conf`, Nginx démarre sans `server` et aucun
port n'écoute. Correction : `tmpfs: /etc/nginx/conf.d:uid=101,gid=101,mode=0755` —
vérifié, `/` et `/gestion-quiz` répondent 200.

### Parcours J1 rejoué (identique à `preuves/J1/04`)

```bash
$ for u in / /gestion-quiz /health; do curl -s -o /dev/null -w "$u -> %{http_code}\n" localhost:8087$u; done
/ -> 200
/gestion-quiz -> 200
/health -> 200

$ curl -s -X POST localhost:8087/api/users -H 'Content-Type: application/json' \
    -d '{"firstname":"Cairne","email":"j2-final-...@example.com"}'
{"id":4,"firstname":"Cairne","email":"j2-final-...@example.com"}   # HTTP 201

$ curl -s -X POST localhost:8087/api/results -H 'Content-Type: application/json' \
    -d '{"userId":4,"score":2,"totalQuestions":2,"answers":[ ... 2 réponses ... ]}'
# HTTP 201

$ docker compose exec -T db psql -U quiz_user -d quiz_db -tAc "select count(*) from quiz_results;"
3

# Login admin + liste (identifiants de démonstration d'`.env.example`)
$ curl -s -X POST localhost:8087/api/admin/login ... | token (173 caractères)
$ curl -s localhost:8087/api/admin/results -H "Authorization: Bearer $TOKEN"
{"results":[{"email":"j2-final-...@example.com", ..., "best_score":2, ...}, ...]}
```

Le compte 3 inclut la ligne `ada@example.com` du volume J1 et les essais précédents : la
base existante est bien réutilisée, pas réinitialisée.

### Persistance `down` / `up`

```bash
$ docker compose down
 Container eval-quiz-app-db-1 Removed
 Network eval-quiz-app_default Removed
$ docker volume ls --format '{{.Name}}' | grep pgdata
eval-quiz-app_pgdata
$ docker compose up -d
# exit 0
$ docker compose ps --format '{{.Service}} {{.Status}}'
backend Up 9 seconds (healthy)
db Up 15 seconds (healthy)
frontend Up 9 seconds (healthy)
$ docker compose exec -T db psql -U quiz_user -d quiz_db -tAc "select count(*) from quiz_results;"
3
$ curl -s -o /dev/null -w '/health -> %{http_code}\n' localhost:8087/health
/health -> 200
```

### Diagnostic conservé

```bash
$ docker compose exec -T backend id
uid=1000(node) gid=1000(node) groups=1000(node)
$ docker compose exec -T backend sh -c 'node -v'
v24.22.3
```

Le shell est toujours utilisable malgré `read_only` et `cap_drop` : le compromis
alpine/débogage de J1 reste valable.
