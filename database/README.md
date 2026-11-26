# Base de données

## Local (Docker Compose)

PostgreSQL 16 dans le service `db`. `init.sql` est monté dans
`/docker-entrypoint-initdb.d/` : il n'est joué qu'à la **première**
initialisation du volume `pgdata`. Rien n'est publié sur l'hôte.

## Cloud (Neon, J5)

PostgreSQL externe, joint par une chaîne `postgres://…?sslmode=require`.
La chaîne est un **secret** : jamais dans le dépôt, jamais dans un script, jamais
dans une capture ou un log.

### 1. Créer la base

Projet Neon, région proche de `francecentral` (Europe). Noter la version de
PostgreSQL. Copier la chaîne de connexion dans un gestionnaire de mots de passe.

### 2. Initialiser le schéma (une seule fois)

`init.sql` n'a pas de `IF NOT EXISTS` : **il n'est pas rejouable**. Le script
refuse de le rejouer si `users` existe déjà.

```bash
read -rs DATABASE_URL && export DATABASE_URL   # saisie masquée, rien dans l'historique
./scripts/init-db.sh                             # attendu : users, quiz_results, answers
```

En local ce n'est pas nécessaire : Compose le fait au premier démarrage du
volume. Sur Neon, personne ne le fait automatiquement, d'où le script.

### 3. Brancher le backend

```bash
./scripts/deploy.sh --skip-build    # avec DATABASE_URL exportée
```

Le script stocke la valeur comme secret `database-url` de l'app et l'expose par
`DATABASE_URL=secretref:database-url` (nouvelle révision).

### TLS

Le backend (`pg` 8.23, `pg-connection-string` 2.14) traite `sslmode=require` comme
`verify-full` : la liaison est chiffrée **et** le certificat du serveur est
vérifié (plus strict que libpq, qui ne vérifie pas avec `require`). Neon présente
un certificat public valide, donc aucune modification de `server.js`. Au
démarrage, `pg` affiche un avertissement qui le rappelle ; il est sans
conséquence. Pour le comportement libpq, il faudrait
`uselibpqcompat=true&sslmode=require` (inutile ici).

### Base injoignable

`GET /health` reste 200 (il ne requiert aucune requête SQL). Les routes `/api/*`
répondent 500 : `/health` ne prouve pas la base.
