# J4 — Frontend et backend dans Azure Container Apps

**Branche(s)** : feature/j4-container-apps
**Dépend de** : J3
**Assigné** : Ulrich & Adam
**Statut** : en cours (déployé et vérifié ; PR à ouvrir)
**Livrables** : suite de `scripts/deploy.sh` (environnement + 2 apps), `docs/deploiement-azure.md` mis à jour, `preuves/J4/`

## Décisions

| Sujet | Recommandation | Coût/risque |
|---|---|---|
| Ingress backend | interne (`--ingress internal --target-port 3007`) | le navigateur ne l'appelle pas directement, tout passe par nginx `/api/` |
| Ingress frontend | externe `--target-port 8080` (nginx-unprivileged) | URL publique, surface limitée à nginx |
| Accès ACR | identité managée + AcrPull | peut être refusé en compte étudiant ; repli admin user documenté |
| Réplicas | `--min-replicas 0` ou `1`, `--max-replicas 1` | 0 = scale-to-zero, démarrage à froid ; 1 = coût permanent |
| Secrets | `--secrets` + `secretref:` sauf valeurs publiques | jamais en clair dans les scripts |

## Point de conception critique

`nginx.conf` pointe sur `backend:3007`. Dans Container Apps, une app à ingress interne se joint par son nom sur le port 80/443 de l'ingress, pas sur 3007. Il faut le paramétrage `BACKEND_HOST`/`BACKEND_PORT` de J1 (Azure : `BACKEND_HOST=<nom-app-backend>`, `BACKEND_PORT=80`). À valider expérimentalement, ne pas supposer.

## Tâches

- [x] Log Analytics + `az containerapp env create` (région de J0) — env `cae-quiz-eval` créé (environnement express, voir docs)
- [x] Backend : `az containerapp create` avec image ACR, ingress interne port 3007, variables PORT=3007, FROM_EMAIL, secrets jwt-secret, admin-password, resend-api-key (valeur factice si Resend non fourni) — ingress **externe** (express, pas d'interne joignable), secrets `secretref:`, pull par identité user-assigned
- [x] Consulter `az containerapp logs show` au démarrage ; si plantage lié à RESEND_API_KEY/DATABASE_URL absents, noter le message exact (diagnostic exigé par docs/03) puis valeur factice non secrète — démarrage sain (`Server running on port 3007`), aucun plantage ; sans DB : `ECONNREFUSED 127.0.0.1:5432` à l'inscription
- [x] Frontend : create avec image ACR, ingress externe 8080, `BACKEND_HOST`/`BACKEND_PORT` — `BACKEND_SCHEME=https`, `BACKEND_HOST=<fqdn backend>`, `BACKEND_PORT=443`
- [x] `az containerapp revision list -n <app> -g $RG -o table` : Running/Healthy — backend et frontend Healthy, 1 réplica
- [x] URL via `az containerapp show -n frontend --query properties.configuration.ingress.fqdn -o tsv` — `preuves/J4/curl-health.txt`
- [x] `curl -i https://<fqdn>/health` = 200 + `{"status":"ok"}` — 200 + `{"status":"ok"}`
- [x] `/` et `/gestion-quiz` chargent — 200 / 200
- [x] Sans PostgreSQL, l'inscription échoue proprement (comportement noté, succès non exigé) — 500 propre, backend toujours up
- [x] `deploy.sh` relançable (create ou update) — deux exécutions consécutives sans échec
- [x] Capturer logs et révisions expurgés — `preuves/J4/`

## Preuve

- [x] Révisions (`preuves/J4/revisions.txt`)
- [x] Sortie de `curl -i /health`
- [x] Logs de démarrage expurgés
- [x] URL du frontend (`curl-health.txt`, FQDN dans `deploy-run*.txt`)
- [ ] Schéma cloud (voir DOC)

## Je sais expliquer (humain)

- [ ] Ingress interne/externe
- [ ] Révision et déclenchement
- [ ] Tirer l'image ACR sans mot de passe
- [ ] Pourquoi `/health` ne prouve pas la base
- [ ] Secret vs variable d'environnement


## Écarts constatés

- Environnement **express** : pas de DNS interne ni de HTTP clair ; backend en ingress externe, restriction d'IP impossible (IP sortantes non exposées). Détails dans `docs/deploiement-azure.md`.
- Le point de conception « `BACKEND_PORT=80` » du plan est invalidé : c'est 443 en HTTPS.
