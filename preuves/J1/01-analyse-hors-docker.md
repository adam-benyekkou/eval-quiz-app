# Preuves J1 — Section 1 : analyse

Machine : Linux, Docker 29.10.0, Node 24 (pour npm), cible conteneur Node 20.
Aucun secret réel n'est présent ci-dessous.

## A. Composants, ports, variables — source

Lus dans le code et `docs/08` :

```text
backend/server.js:9    PORT = process.env.PORT || 3007
backend/server.js:48   new pg.Pool({ connectionString: process.env.DATABASE_URL, ... })
backend/server.js:55   new Resend(process.env.RESEND_API_KEY)
backend/server.js:58-62 ADMIN_USERNAME, ADMIN_PASSWORD, JWT_SECRET, FROM_EMAIL
backend/server.js:437  GET /health -> res.json({ status: "ok" })
main.js:3              const API_URL = "/api";
main.js:11             import.meta.glob("./questions_*.js")
vite.config.js         inputs: index.html, gestion-quiz.html ; publicDir public
```

Synthèse dans `docs/architecture-locale.md` §1 à §5.

## B. Doublon de configuration Nginx

```bash
$ diff nginx/nginx.conf database/nginx/nginx.conf && echo "IDENTIQUES"
IDENTIQUES
```

Les deux fichiers sont identiques. `nginx/nginx.conf` est utilisé comme template du
conteneur frontend ; `database/nginx/nginx.conf` n'est référencé par aucun build.

## C. Backend hors Docker — sans `RESEND_API_KEY`

```bash
$ cd backend && npm install --no-audit --no-fund
added 177 packages in 11s
# exit 0
$ ls package-lock.json
package-lock.json        # lock absent du dépôt à l'origine, généré ici (voir J1 §2)

$ env -u DATABASE_URL -u RESEND_API_KEY PORT=3007 node server.js
Error: Missing API key. Pass it to the constructor `new Resend("re_123")`
    at new Resend (.../node_modules/resend/dist/index.mjs:312:15)
    at file:///home/adam/Cours/eval-quiz-app/backend/server.js:55:16
# exit != 0 : le processus meurt à l'import, /health ne répond même pas
$ curl -s -i --max-time 3 localhost:3007/health
# (aucune réponse, connexion refusée)
```

**Conclusion** : `RESEND_API_KEY` est obligatoire au démarrage, valeur factice suffisante.

## D. Backend hors Docker — avec clé factice, sans PostgreSQL

```bash
$ env -u DATABASE_URL RESEND_API_KEY=re_dummy PORT=3007 node server.js
Server running on port 3007

$ curl -s -o /dev/null -w '%{http_code}\n' --max-time 3 localhost:3007/health
200
$ curl -s --max-time 3 localhost:3007/health
{"status":"ok"}

$ curl -s -i --max-time 6 -X POST localhost:3007/api/users \
    -H 'Content-Type: application/json' \
    -d '{"firstname":"Test","email":"test@example.com"}'
HTTP/1.1 500 Internal Server Error
{"error":"Internal server error"}

# logs serveur :
Error creating user: AggregateError [ECONNREFUSED]:
    code: 'ECONNREFUSED', ... connect ECONNREFUSED 127.0.0.1:5432
```

**Conclusions** :

- Sans PostgreSQL, le backend **démarre** et `/health` répond 200 : le healthcheck backend ne prouve pas la connexion SQL. D'où le `depends_on: service_healthy` sur `db` côté Compose.
- Sans PostgreSQL, `POST /api/users` renvoie 500 : le pool est créé sans erreur, l'échec est à la première requête.
- Le démarrage hors Docker est donc possible ; seule la chaîne email est décorative sans clé réelle.
