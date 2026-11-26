# J6 — CI/CD GitHub Actions

**Branche(s)** (ordre) : feature/j6-ci-images (J6-A : build images + Trivy image bloquant CRITICAL), feature/j6-branch-protection (J6-A : protection de `main` et checks requis, documentation et preuves, réglages faits dans l'interface), feature/j6-cd-azure (J6-B : publication ACR + mise à jour Container Apps après fusion), feature/j6-demo-question (J6-D)
**Dépend de** : J1, J2 pour J6-A ; J3, J4 pour J6-B
**Assigné** : _à renseigner_
**Statut** : à faire
**Livrables** : `.github/workflows/ci.yml`, `.github/workflows/cd.yml`, `docs/cicd.md`, `preuves/J6/`

## Existant à ne pas casser

`trivy.yml` (scan filesystem, bloquant CRITICAL + HIGH) et `hadolint.yml` restent. Ils ne remplacent pas le scan sur images construites exigé par docs/04.

Recommandation : garder `trivy.yml` tel quel (plus strict), ajouter le job image, ne requérir que les checks dont les noms ont été vus dans une exécution réelle.

## Section 1 — feature/j6-ci-images

- [ ] `ci.yml` sur `pull_request` vers `main`, `permissions: contents: read`
- [ ] Job `build` : `docker/setup-buildx-action`, build des deux images sans push, `load: true`
- [ ] Job `trivy-image` (`needs: build`) : `aquasecurity/trivy-action` sur chaque image, `severity: CRITICAL`, `exit-code: 1`, `ignore-unfixed` à décider et justifier, aucun `continue-on-error`
- [ ] Rapport Trivy en artefact (`actions/upload-artifact`)
- [ ] Vérifier le blocage de façon contrôlée (scan local, ou branche jetable d'un tag connu pour contenir un CRITICAL, jamais poussé dans l'ACR) : constater exit code 1, supprimer la branche
- [ ] PR de test `feature/test-pr` (modification Markdown) : tous les checks s'exécutent
- [ ] Noter les noms exacts des checks publiés (ex. `build`, `trivy-image`, `Trivy security scan` / `trivy`, `Hadolint` / `hadolint`)

## Section 2 — feature/j6-branch-protection

À faire après la première exécution réussie de la CI (docs/04 B.5).

- [ ] Settings > Branches (ou Rulesets) : règle sur `main`
- [ ] Require PR before merging ; revue approuvée si possible (second compte du groupe)
- [ ] Require status checks : uniquement les noms réellement publiés
- [ ] Interdire suppression et force-push
- [ ] Règle en mode actif (pas en évaluation)
- [ ] Test négatif : `git push origin main` direct refusé (sans force, sans modifications non sauvegardées)
- [ ] Test négatif : PR avec check en échec non fusionnable
- [ ] Si le plan GitHub ne permet pas l'application : le dire dans `docs/cicd.md` avec une mesure de remplacement, sans prétendre que la règle est active
- [ ] Captures : règle active, PR, checks, fusion

## Section 3 — feature/j6-cd-azure

- [ ] `cd.yml` uniquement sur `push` vers `main` (jamais `pull_request`) ; `concurrency`
- [ ] Auth Azure par OIDC (`azure/login` avec client-id, tenant-id, subscription-id en variables/secrets, `permissions: id-token: write`) ; identifiant fédéré limité à `repo:adam-benyekkou/eval-quiz-app:ref:refs/heads/main` et rôle minimal (Contributor limité au resource group + AcrPush)
- [ ] Si J0 a montré que c'est impossible : secrets CI strictement protégés, environnement GitHub `production`, limite documentée
- [ ] Build, tag `${{ github.sha }}` (court), push vers `$ACR_NAME.azurecr.io/quiz-backend:<sha>` et `quiz-frontend:<sha>`
- [ ] Scan Trivy avant push (même politique que la CI) ou réutilisation de l'image validée : choix justifié
- [ ] `az containerapp update -n backend --image ...:<sha>` puis frontend (nouvelle révision à chaque merge)
- [ ] Étape de contrôle : liste des révisions + `curl /health` sans exiger de succès SQL
- [ ] Aucun secret dans les logs (`::add-mask::` si valeur dynamique affichée)
- [ ] Secrets Azure non exposés aux PR

## Section 4 — feature/j6-demo-question

- [ ] Choisir une question dans `questions_docker.js` (donnée, pas logique) ; modification minime
- [ ] Parcours complet : branche, PR vers `main` du fork, CI verte, approbation, fusion
- [ ] Le CD se déclenche seul : image taguée avec le SHA de fusion, nouvelle révision visible
- [ ] Si J5 fonctionne, la question modifiée apparaît dans l'app déployée
- [ ] Chronométrer (cible < 5 min avec cache)

## Preuve

- [ ] URL de PR
- [ ] Exécutions CI et CD
- [ ] Rapports Trivy
- [ ] Tags/digests ACR
- [ ] Révisions Azure
- [ ] Captures de protection de branche

## Je sais expliquer (humain)

- [ ] Pourquoi le déploiement ne tourne pas sur `pull_request`
- [ ] OIDC et droits du service principal
- [ ] Pourquoi nommer les checks et attendre la première exécution
- [ ] Exit-code 1 bloquant vs rapport seul
- [ ] Retrouver quelle révision correspond à quel commit
