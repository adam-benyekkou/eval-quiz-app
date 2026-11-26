# Preuves J2 — Section 1 : baseline Trivy (aucune correction)

Toutes les commandes sont exécutées depuis la racine du dépôt, sur l'état J1
(`main` = `456077a`), images construites sans modification.

## A. Images « telles que livrées »

```bash
$ docker build -t quiz-backend:baseline backend
# exit 0
$ docker build -t quiz-frontend:baseline .
# exit 0

$ docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep baseline
quiz-frontend:baseline 92.4MB
quiz-backend:baseline 225MB
```

## B. Versions réellement embarquées

```bash
$ docker run --rm quiz-backend:baseline sh -c 'node -e "console.log(process.version)"; npm --version'
v20.20.2
10.8.2

$ docker run --rm quiz-frontend:baseline nginx -v
nginx version: nginx/1.31.7
```

Trivy détecte `alpine 3.23.4` (backend) et `alpine 3.24.2` (frontend).

## C. Scans de vulnérabilités

```bash
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
    aquasec/trivy:latest image --severity CRITICAL,HIGH,MEDIUM \
    --format table quiz-backend:baseline > preuves/J2/trivy-avant-backend.txt
# exit 0
$ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock -v trivy-cache:/root/.cache/ \
    aquasec/trivy:latest image --severity CRITICAL,HIGH,MEDIUM \
    --format json quiz-backend:baseline > preuves/J2/trivy-avant-backend.json
# exit 0
# idem frontend -> trivy-avant-frontend.{txt,json}
```

Dépouillement (`trivy-avant-*.json`) :

| Image | Cible | CRITICAL | HIGH | MEDIUM | Total |
| --- | --- | ---: | ---: | ---: | ---: |
| backend | Alpine 3.23.4 | 0 | 7 | 21 | 28 |
| backend | npm embarqué | 1 | 21 | 16 | 38 |
| frontend | Alpine 3.24.2 | 1 | 13 | 13 | 27 |

Trivy 0.76.2 ; base `mirror.gcr.io/aquasec/trivy-db` téléchargée le 2026-11-26.

## D. Provenance des paquets npm vulnérables

Ils appartiennent au npm fourni par l'image `node:20-alpine`, pas à `/app/node_modules` :

```bash
$ docker run --rm quiz-backend:baseline sh -c 'for p in tar pacote sigstore brace-expansion; do
    a=$(node -p "try{require(\"/app/node_modules/$p/package.json\").version}catch(e){\"absent\"}")
    n=$(node -p "try{require(\"/usr/local/lib/node_modules/npm/node_modules/$p/package.json\").version}catch(e){\"absent\"}")
    echo "$p app=$a npm=$n"; done'
tar app=absent npm=6.2.1
pacote app=absent npm=18.0.6
sigstore app=absent npm=2.3.1
brace-expansion app=2.1.8 npm=2.0.1
```

`tar`/`pacote`/`sigstore` sont absents de l'application ; `brace-expansion` y est déjà en
version corrigée. Les CVE npm sont donc des outils de build embarqués, non du code métier.

## E. Scan de configuration

```bash
$ docker run --rm -v "$PWD":/src aquasec/trivy:latest \
    config --severity CRITICAL,HIGH,MEDIUM,LOW /src > preuves/J2/trivy-config-avant.txt
# exit 0
```

Résultat : 0 CRITICAL/HIGH/MEDIUM. Une seule règle LOW par Dockerfile, `DS-0026`
(absence de `HEALTHCHECK`), traitée en section 2.

## F. Scan de secrets

```bash
$ docker run --rm -v "$PWD":/src -w /src aquasec/trivy:latest \
    fs --scanners secret --skip-dirs node_modules --skip-dirs .git . \
    > preuves/J2/trivy-secret-avant.txt
# exit 0 — aucun secret détecté
```

Contrôle positif (fichiers factices dans `/tmp/opencode/trivy-secret-test`) pour prouver
que le scanner détecte réellement :

```bash
$ docker run --rm -v /tmp/opencode/trivy-secret-test:/src -w /src aquasec/trivy:latest \
    fs --scanners secret --format json .
github.txt github-pat GitHub Personal Access Token CRITICAL
stripe.txt stripe-secret-token Stripe Secret Key CRITICAL
```

Le dépôt réel ne contient ni jeton ni clé ; `.env` est ignoré par Git (vérifié en J1).
