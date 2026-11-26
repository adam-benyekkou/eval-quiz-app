# J5 — PostgreSQL cloud (Neon)

**Branche(s)** : feature/j5-neon
**Dépend de** : J4
**Assigné** : _à renseigner_
**Statut** : à faire
**Livrables** : `database/README.md` (procédure d'init, sans secret), mise à jour de `scripts/deploy.sh` (injection du secret), `preuves/J5/`. Un échec ici n'annule pas J1 à J4 ni J6 (docs/03).

## Contraintes

- La chaîne Neon est un secret : saisie interactive ou variable d'environnement de l'humain ; jamais dans le dépôt, jamais envoyée à une IA, jamais dans une capture.
- PostgreSQL local reste dans Compose (docs/02).

## Tâches

- [ ] Créer le projet Neon (région proche d'Azure), noter la version PG
- [ ] Récupérer la chaîne avec `?sslmode=require`, la stocker dans un gestionnaire de mots de passe
- [ ] Hypothèse à tester : pg 8 + `sslmode=require` suffit sans modifier `server.js` (test local `DATABASE_URL='<chaîne>' node backend/server.js` puis POST `/api/users`)
- [ ] Si échec TLS : noter l'erreur exacte et corriger par configuration avant tout changement de code (périmètre « ne pas modifier la logique métier » : demander au formateur)
- [ ] `psql "$DATABASE_URL" -f database/init.sql` une seule fois (pas de `IF NOT EXISTS`) ; vérifier `\dt` (users, quiz_results, answers)
- [ ] Documenter la procédure et le caractère non rejouable dans `database/README.md`
- [ ] `az containerapp secret set -n backend -g $RG --secrets database-url=<valeur>` (valeur lue d'une variable locale, jamais écrite dans le script)
- [ ] `az containerapp update -n backend -g $RG --set-env-vars DATABASE_URL=secretref:database-url` (nouvelle révision)
- [ ] Révision Healthy et logs sans fuite
- [ ] Parcours via l'URL du frontend (inscription, quiz, résultat)
- [ ] Vérifier côté Neon : `select count(*) from quiz_results;`
- [ ] Persistance après `az containerapp revision restart`
- [ ] Relire logs et captures : aucune chaîne visible

## Preuve

- [ ] Parcours fonctionnel
- [ ] Sortie de `\dt`
- [ ] Comptage avant/après redémarrage
- [ ] Explication de la gestion des secrets

## Je sais expliquer (humain)

- [ ] Pourquoi TLS est obligatoire et ce que fait `sslmode=require` (chiffre, ne vérifie pas comme verify-full)
- [ ] Où vit le secret et comment il arrive dans le conteneur
- [ ] Pourquoi `init.sql` est lancé à la main ici et automatiquement en local
- [ ] Comportement quand la base est injoignable (`/health` et routes API)
