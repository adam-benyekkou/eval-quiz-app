# J3 — Azure CLI et ACR

**Branche(s)** : feature/j3-azure-scripts
**Dépend de** : J0, J1, J2
**Assigné** : Ulrich & Adam
**Statut** : à faire
**Livrables** : `scripts/deploy.sh` (infra + ACR à ce stade), `scripts/destroy.sh`, `scripts/lib.sh`, `docs/deploiement-azure.md`, `preuves/J3/`

## Contraintes

- Scripts idempotents et sans secret (variables d'environnement ou `az` authentifié).
- Noms centralisés dans `scripts/lib.sh` (RG, LOCATION, ACR_NAME, ENV_NAME, TAG).
- `set -euo pipefail` et vérification des prérequis (az, docker, connexion).
- `destroy.sh` demande une confirmation explicite et ne supprime que le groupe du projet.

## Tâches

- [ ] `lib.sh` (require_cmd, log)
- [ ] `deploy.sh` étape 1 : `az group create`
- [ ] `az acr create --sku Basic` (admin user désactivé par défaut ; l'activer seulement si J0 montre AcrPull impossible, et documenter)
- [ ] Tag traçable `TAG=$(git rev-parse --short HEAD)`, jamais seulement `latest`
- [ ] `az acr login -n $ACR_NAME`, docker tag/push vers `$ACR_NAME.azurecr.io/quiz-backend:$TAG` et `quiz-frontend:$TAG`
- [ ] Alternative `az acr build` à comparer
- [ ] `az acr repository list -n $ACR_NAME -o table` et `az acr repository show-tags -n $ACR_NAME --repository quiz-backend -o table`
- [ ] `destroy.sh` : `az group delete -n $RG --yes --no-wait` après confirmation
- [ ] Relancer `deploy.sh` deux fois sans échec
- [ ] `docs/deploiement-azure.md` (prérequis, commandes, opérations sensibles, nettoyage)
- [ ] `shellcheck scripts/*.sh` propre

## Preuve

- [ ] Sortie de `show-tags`
- [ ] Sortie de `deploy.sh` expurgée
- [ ] Scripts versionnés

## Je sais expliquer (humain)

- [ ] Rôle du resource group et destroy en bloc
- [ ] Tag SHA vs `latest`
- [ ] Script idempotent
- [ ] Coût d'ACR Basic et ce qui reste facturé
