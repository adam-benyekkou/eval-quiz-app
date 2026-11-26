# J3 — Azure CLI et ACR

**Branche(s)** : feature/j3-azure-scripts
**Dépend de** : J0, J1, J2
**Assigné** : Ulrich & Adam
**Statut** : en cours (scripts et ACR validés, images publiées ; PR à ouvrir)
**Livrables** : `scripts/deploy.sh` (infra + ACR à ce stade), `scripts/destroy.sh`, `scripts/lib.sh`, `docs/deploiement-azure.md`, `preuves/J3/`

## Contraintes

- Scripts idempotents et sans secret (variables d'environnement ou `az` authentifié).
- Noms centralisés dans `scripts/lib.sh` (RG, LOCATION, ACR_NAME, ENV_NAME, TAG).
- `set -euo pipefail` et vérification des prérequis (az, docker, connexion).
- `destroy.sh` demande une confirmation explicite et ne supprime que le groupe du projet.

## Tâches

- [x] `lib.sh` (require_cmd, log)
- [x] `deploy.sh` étape 1 : `az group create`
- [x] `az acr create --sku Basic` (admin user désactivé par défaut ; l'activer seulement si J0 montre AcrPull impossible, et documenter) — `adminUserEnabled=False` vérifié, J0 a validé AcrPull par identité managée
- [x] Tag traçable `TAG=$(git rev-parse --short HEAD)`, jamais seulement `latest` — `70251de`
- [x] `az acr login -n $ACR_NAME`, docker tag/push vers `$ACR_NAME.azurecr.io/quiz-backend:$TAG` et `quiz-frontend:$TAG`
- [x] Alternative `az acr build` à comparer — testée : refusée par l'abonnement (`TasksOperationsNotAllowed`), chemin local retenu, comparaison documentée
- [x] `az acr repository list -n $ACR_NAME -o table` et `az acr repository show-tags -n $ACR_NAME --repository quiz-backend -o table`
- [x] `destroy.sh` : `az group delete -n $RG --yes --no-wait` après confirmation — garde-fou testé sans suppression réelle (ACR conservé pour J4)
- [x] Relancer `deploy.sh` deux fois sans échec — deux exécutions consécutives à 0
- [x] `docs/deploiement-azure.md` (prérequis, commandes, opérations sensibles, nettoyage)
- [x] `shellcheck scripts/*.sh` propre — via conteneur `koalaman/shellcheck`, exit 0

## Preuve

- [x] Sortie de `show-tags` — `preuves/J3/02-deploy.md`
- [x] Sortie de `deploy.sh` expurgée — `preuves/J3/02-deploy.md`
- [x] Scripts versionnés — commit sur `feature/j3-azure-scripts`

Détail des preuves :

- `preuves/J3/01-shellcheck.md`
- `preuves/J3/02-deploy.md` (deux exécutions, incident DNS transitoire noté)
- `preuves/J3/03-destroy-garde-fou.md`
- `preuves/J3/04-acr-build-refus.md`
- `preuves/J3/05-ressources.md`

## Je sais expliquer (humain)

- [ ] Rôle du resource group et destroy en bloc
- [ ] Tag SHA vs `latest`
- [ ] Script idempotent
- [ ] Coût d'ACR Basic et ce qui reste facturé
