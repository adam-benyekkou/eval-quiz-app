# J5 — PostgreSQL cloud (Neon)

**Branche(s)** : feature/j5-neon
**Dépend de** : J4
**Assigné** : Ulrich & Adam
**Statut** : en cours (déployé et vérifié ; PR à ouvrir)
**Livrables** : `database/README.md` (procédure d'init, sans secret), mise à jour de `scripts/deploy.sh` (injection du secret), `preuves/J5/`. Un échec ici n'annule pas J1 à J4 ni J6 (docs/03).

## Contraintes

- La chaîne Neon est un secret : saisie interactive ou variable d'environnement de l'humain ; jamais dans le dépôt, jamais envoyée à une IA, jamais dans une capture.
- PostgreSQL local reste dans Compose (docs/02).

## Tâches

- [x] Créer le projet Neon (région proche d'Azure), noter la version PG — projet `quiz-eval`, `aws-eu-central-1` (Francfort), PostgreSQL 18.7
- [x] Récupérer la chaîne avec `?sslmode=require`, la stocker dans un gestionnaire de mots de passe — fichier local `.env.neon-url` (chmod 600, ignoré par git)
- [x] Hypothèse à tester : pg 8 + `sslmode=require` suffit sans modifier `server.js` (test local `DATABASE_URL='<chaîne>' node backend/server.js` puis POST `/api/users`) — confirmée : inscription 201 en local sans modifier `server.js`
- [x] Si échec TLS : noter l'erreur exacte et corriger par configuration avant tout changement de code (périmètre « ne pas modifier la logique métier » : demander au formateur) — sans objet, pas d'échec
- [x] `psql "$DATABASE_URL" -f database/init.sql` une seule fois (pas de `IF NOT EXISTS`) ; vérifier `\dt` (users, quiz_results, answers) — via `scripts/init-db.sh`, `preuves/J5/01-init-db.txt`
- [x] Documenter la procédure et le caractère non rejouable dans `database/README.md` — `database/README.md`
- [x] `az containerapp secret set -n backend -g $RG --secrets database-url=<valeur>` (valeur lue d'une variable locale, jamais écrite dans le script) — fait par `deploy.sh`, valeur lue de l'environnement
- [x] `az containerapp update -n backend -g $RG --set-env-vars DATABASE_URL=secretref:database-url` (nouvelle révision) — nouvelle révision
- [x] Révision Healthy et logs sans fuite — Healthy ; 0 occurrence de chaîne dans les logs
- [x] Parcours via l'URL du frontend (inscription, quiz, résultat) — inscription + résultat, `preuves/J5/02-parcours-azure.txt`
- [x] Vérifier côté Neon : `select count(*) from quiz_results;` — 2 users, 1 quiz_results, 1 answers
- [x] Persistance après `az containerapp revision restart` — `revision restart` indisponible en express ; nouvelle révision forcée, count inchangé (`03-persistance-apres-revision.txt`)
- [x] Relire logs et captures : aucune chaîne visible — vérifié par recherche de la chaîne et du mot de passe

## Preuve

- [x] Parcours fonctionnel
- [x] Sortie de `\dt`
- [x] Comptage avant/après redémarrage
- [x] Explication de la gestion des secrets

## Je sais expliquer (humain)

- [ ] Pourquoi TLS est obligatoire et ce que fait `sslmode=require` (libpq : chiffre sans vérifier ; `pg` 8.23 le traite comme verify-full, vérifie donc le certificat)
- [ ] Où vit le secret et comment il arrive dans le conteneur
- [ ] Pourquoi `init.sql` est lancé à la main ici et automatiquement en local
- [ ] Comportement quand la base est injoignable (`/health` et routes API)
