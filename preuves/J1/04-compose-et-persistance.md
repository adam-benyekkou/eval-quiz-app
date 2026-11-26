# Preuves J1 — Section 4 : Docker Compose et persistance

Environnement : Docker 29.10.0 / Compose v5.8.0. `.env` local copié depuis
`.env.example`, `RESEND_API_KEY=re_fake_local_only` (factice), mot de passe PostgreSQL
fictif. Aucune valeur réelle ni secret dans ce fichier.

## A. `.env` ignoré par git

```bash
$ git check-ignore -v .env
.gitignore:161:.env	.env
# exit 0
```

## B. Démarrage

```bash
$ docker compose up -d --build
Network eval-quiz-app_default Created
Volume eval-quiz-app_pgdata Created
Container eval-quiz-app-db-1 Started
Container eval-quiz-app-db-1 Waiting
Container eval-quiz-app-db-1 Healthy
Container eval-quiz-app-backend-1 Started
Container eval-quiz-app-frontend-1 Started
# exit 0

$ docker compose ps
NAME                       IMAGE                 SERVICE    STATUS                    PORTS
eval-quiz-app-backend-1    quiz-backend:local    backend    Up                        3007/tcp
eval-quiz-app-db-1         postgres:16-alpine    db         Up (healthy)              5432/tcp
eval-quiz-app-frontend-1   quiz-frontend:local   frontend   Up                        0.0.0.0:8087->8080/tcp
```

`db` et `backend` n'exposent aucun port hôte : seulement `3007/tcp` et `5432/tcp` internes.

## C. Parcours via `http://localhost:8087`

Inscription et soumission du résultat par les endpoints appelés par l'interface
(`main.js:94` et `main.js:195`) ; le clic-à-clic du questionnaire n'est pas automatisé.

```bash
$ for u in / /gestion-quiz /health; do curl -s -o /dev/null -w "$u -> %{http_code}\n" localhost:8087$u; done
/ -> 200
/gestion-quiz -> 200
/health -> 200

$ curl -s localhost:8087/health
{"status":"ok"}

$ curl -s -i -X POST localhost:8087/api/users -H 'Content-Type: application/json' \
    -d '{"firstname":"Ada","email":"ada@example.com"}' | tail -1
{"id":1,"firstname":"Ada","email":"ada@example.com"}          # HTTP 201

$ curl -s -i -X POST localhost:8087/api/results -H 'Content-Type: application/json' \
    -d '{"userId":1,"score":2,"totalQuestions":3,"answers":[{...},{...},{...}]}' | tail -1
{"message":"Results saved and email sent","quizResultId":1}    # HTTP 201

$ docker compose exec -T db psql -U quiz_user -d quiz_db -tAc "select count(*) from quiz_results;"
1
```

Captures : `quiz-page.png` (page `/`) et `gestion-quiz-login.png` (`/gestion-quiz`).

## D. Administration

```bash
$ TOKEN=$(curl -s -X POST localhost:8087/api/admin/login \
    -H 'Content-Type: application/json' -d '{"username":"admin","password":"changeme"}' \
    | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
$ echo ${#TOKEN}
173

$ curl -s localhost:8087/api/admin/results -H "Authorization: Bearer $TOKEN"
{"results":[{"email":"ada@example.com","firstname":"Ada","attempts":"1",
 "best_score":2,"total_questions":3,"avg_score":"2.0",
 "last_attempt":"2026-11-26T10:31:26.025Z"}],
 "pagination":{"page":1,"limit":20,"total":1,"totalPages":1}}
```

Identifiants de test : ceux d'`.env.example` (`admin` / `changeme`), à remplacer hors démo.

## E. Resend non configuré : enregistrement réussi malgré l'échec email

Clé factice (401 côté Resend). Le résultat est **enregistré** (HTTP 201, `quizResultId:1`,
count SQL = 1), l'échec email est seulement journalisé :

```text
Failed to send email to ada@example.com: {
  message: 'API key is invalid', name: 'validation_error', statusCode: 401
}
```

**Comportement exact à connaître** : la réponse HTTP dit `"Results saved and email sent"`
alors que l'email a échoué. Message codé en dur (`backend/server.js:345-348`) ; l'échec
d'envoi est absorbé par le `try/catch` de `sendResultEmail` (`:415-433`). Ne pas modifier
la logique métier (règle 8 du plan) : documenté ici, à signaler à l'oral.

## F. Persistance après `docker compose down` (sans `-v`)

```bash
$ docker compose exec -T db psql -U quiz_user -d quiz_db -tAc "select count(*) from quiz_results;"
1

$ docker compose down
 Container eval-quiz-app-frontend-1 Removed
 Container eval-quiz-app-backend-1 Removed
 Container eval-quiz-app-db-1 Removed
 Network eval-quiz-app_default Removed

$ docker volume ls --format '{{.Name}}' | grep pgdata
eval-quiz-app_pgdata                     # le volume survit sans les conteneurs

$ docker compose up -d
Container eval-quiz-app-db-1 Started
Container eval-quiz-app-backend-1 Started
Container eval-quiz-app-frontend-1 Started

$ docker compose ps --format '{{.Service}} {{.Status}}'
backend Up 7 seconds
db Up 13 seconds (healthy)
frontend Up 6 seconds

$ docker compose exec -T db psql -U quiz_user -d quiz_db -tAc "select count(*) from quiz_results;"
1                                         # identique : données conservées

$ curl -s -o /dev/null -w '/health -> %{http_code}\n' localhost:8087/health
/health -> 200
```

## G. `init.sql` non rejoué au second démarrage

```bash
$ docker compose logs db | grep -i "Skipping initialization"
PostgreSQL Database directory appears to contain a database; Skipping initialization
```

Le script monté dans `/docker-entrypoint-initdb.d/` n'est exécuté qu'au premier démarrage
sur un volume vide (`database/init.sql` n'est pas idempotent : pas de `IF NOT EXISTS`).

## H. Explication du volume

Volume nommé `pgdata` monté sur `/var/lib/postgresql/data`.

- `docker compose down` supprime conteneurs et réseau, **pas** les volumes nommés : les
  données restent.
- `docker compose down -v` supprime aussi le volume : base vide, `init.sql` rejoué au
  démarrage suivant.
- Un bind mount aurait dépendu d'un chemin hôte (droits, portabilité) ; le volume nommé
  est géré par Docker et se recrée au bon propriétaire (`postgres`, uid 70 dans l'image).
