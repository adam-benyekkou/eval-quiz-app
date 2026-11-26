# J1 — Conteneurisation locale (Docker, Compose, PostgreSQL persistant)

**Branche(s)** : feature/j1-analyse, feature/j1-backend-image, feature/j1-frontend-image, feature/j1-compose (une PR par branche, dans cet ordre)
**Dépend de** : — ; doit être validé avant J3
**Assigné** : Ulrich & Adam
**Statut** : en cours (sections 1-3 faites)
**Livrables** : `backend/Dockerfile`, `Dockerfile` (frontend), `docker-compose.yml`, `.dockerignore`, `backend/.dockerignore`, `.env.example` à jour, `docs/architecture-locale.md` + schéma, `preuves/J1/`

## Section 1 — feature/j1-analyse (docs/08 §8)

- [x] Lister les composants, rôles et dépendances : frontend Vite, nginx, backend Express, PostgreSQL, Resend
- [x] Ports : 5173 (dev Vite), 3007 (backend), 5432 (PG), 80 (nginx conteneur) ; décider le port hôte (ex. 8087)
- [x] Variables : séparer publiques (POSTGRES_DB, FROM_EMAIL, PORT) et secrets (POSTGRES_PASSWORD, DATABASE_URL, RESEND_API_KEY, ADMIN_PASSWORD, JWT_SECRET)
- [x] Lire `backend/server.js` (routes, corps, codes HTTP, `/health`, usage de RESEND_API_KEY)
- [x] Comprendre `database/nginx/nginx.conf` (doublon de `nginx/nginx.conf` ?) et décider lequel est utilisé
- [x] Vérifier hors Docker que le backend démarre sans RESEND_API_KEY et sans PostgreSQL : `cd backend && npm ci && PORT=3007 node server.js` puis `curl -i localhost:3007/health` ; noter le résultat (conditionne J4)
- [x] Rédiger `docs/architecture-locale.md` avec un schéma réalisé par le groupe (Mermaid ou image)
- [x] Rédiger la justification des images de base et du volume nommé, en incluant le choix d'alpine plutôt que distroless/Chainguard (garder le shell pour le débogage, compromis assumé plutôt que surface d'attaque minimale)

## Section 2 — feature/j1-backend-image

- [x] Image `node:20-alpine` (Node ≥ 20), tag précis, pas `latest` — **décision prise** : on garde alpine (shell + `apk` disponibles), pas distroless/Chainguard, pour conserver `docker exec -it <ctn> sh` en débogage ; à justifier à l'oral comme un compromis explicite (surface d'attaque légèrement plus large contre accès de diagnostic direct), pas une méconnaissance de l'alternative durcie
- [x] `COPY package*.json` puis `npm ci --omit=dev` puis COPY du code
- [x] `USER node`, `EXPOSE 3007`, `CMD ["node","server.js"]`
- [x] `backend/.dockerignore` (node_modules, .env*, .git)
- [x] Vérifier la présence de `package-lock.json` dans `backend/` (si absent, `npm ci` échoue : utiliser `npm install --omit=dev` et le justifier, ou générer le lock dans une PR dédiée)
- [x] `docker build -t quiz-backend:local backend && docker run --rm -p 3007:3007 quiz-backend:local`
- [x] `curl -i localhost:3007/health` = 200 + `{"status":"ok"}`
- [x] Hadolint local : `docker run --rm -i hadolint/hadolint < backend/Dockerfile`

## Section 3 — feature/j1-frontend-image (Dockerfile racine)

- [x] Étape 1 : `node:20-alpine`, `npm ci`, `npm run build` (dist/, deux pages d'entrée d'après vite.config.js)
- [x] Étape 2 : nginx, `nginxinc/nginx-unprivileged:alpine` (non-root, port 8080, shell conservé pour le débogage), copier dist/ dans `/usr/share/nginx/html`
- [x] Paramétrer le backend dans la config nginx (modèle `*.template` + envsubst, variables `BACKEND_HOST` et `BACKEND_PORT` ; Compose : backend/3007 ; Azure en J4 : valeurs différentes)
- [x] Conserver les routes `/api/`, `/health`, `/gestion-quiz`
- [x] `.dockerignore` racine (node_modules, dist, .git, .env*, plan, docs, preuves)
- [x] Build local ; `/` et `/gestion-quiz` répondent 200
- [x] Hadolint propre

## Section 4 — feature/j1-compose

- [ ] Services `db` (postgres:16-alpine), `backend`, `frontend`
- [ ] db : variables POSTGRES_* depuis `.env`, volume nommé `pgdata:/var/lib/postgresql/data`, healthcheck `pg_isready`
- [ ] Init du schéma via montage `./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro` (exécuté seulement à la première initialisation du volume ; à expliquer à l'oral)
- [ ] backend : `DATABASE_URL=postgres://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}`, `depends_on` db condition `service_healthy`, secrets via `.env`
- [ ] frontend : `depends_on` backend ; un seul port hôte (ex. `8087:8080`) ; db et backend non publiés
- [ ] `.env.example` complet (valeurs fictives, RESEND_API_KEY vide ou factice)
- [ ] Vérifier que `.env` est ignoré : `git check-ignore -v .env`
- [ ] `docker compose up -d --build` : services healthy/running
- [ ] Parcours : inscription, quiz complet, résultat enregistré (`docker compose exec db psql -U $POSTGRES_USER -d $POSTGRES_DB -c "select count(*) from quiz_results;"`)
- [ ] Admin `/gestion-quiz` : login + liste
- [ ] Persistance : `docker compose down` (sans -v) puis `up` puis même count
- [ ] Si Resend non configuré : vérifier que l'enregistrement réussit quand même, ou documenter le comportement exact

## Preuve

- [ ] `preuves/J1/` : commandes, logs expurgés, captures
- [ ] Test de persistance avant/après `docker compose down`
- [ ] Explication du volume

## Je sais expliquer (humain)

- [ ] Multi-étapes et USER node / nginx non-root
- [ ] COPY package*.json avant le code
- [ ] /docker-entrypoint-initdb.d et non-rejeu de init.sql
- [ ] Pourquoi db et backend ne sont pas publiés
- [ ] `down` vs `down -v`
