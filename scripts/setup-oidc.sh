#!/usr/bin/env bash
#
# J6-B — Prépare l'authentification OIDC de GitHub Actions vers Azure, sans
# service principal (création refusée sur Azure for Students, voir J0) :
# identité managée user-assigned + identifiant fédéré limité à la branche main
# de ce dépôt. Aucun mot de passe ni secret client n'existe.
# Rôles minimaux : AcrPush sur l'ACR, Contributor sur le seul resource group.
# Idempotent. Les identifiants (client, tenant, abonnement) sont enregistrés
# comme secrets GitHub (masqués dans les logs) si `gh` est connecté.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

DEPLOY_IDENTITY="${DEPLOY_IDENTITY:-id-quiz-github-deploy}"
GH_REPO="${GH_REPO:-adam-benyekkou/eval-quiz-app}"
FED_NAME="github-main"
# GitHub présente le sujet OIDC avec les identifiants NUMÉRIQUES du propriétaire et
# du dépôt (repo:<owner>@<id>/<repo>@<id>:ref:…), pas avec les noms : le format
# par nom ne correspond à aucune assertion (erreur AADSTS700213).
OWNER_ID="$(gh api "repos/${GH_REPO}" --jq .owner.id)"
REPO_ID="$(gh api "repos/${GH_REPO}" --jq .id)"
SUBJECT="repo:${GH_REPO%%/*}@${OWNER_ID}/${GH_REPO#*/}@${REPO_ID}:ref:refs/heads/main"

require_cmd az
require_cmd gh
require_az_login

log "Identité de déploiement ${DEPLOY_IDENTITY}"
az identity create --name "${DEPLOY_IDENTITY}" --resource-group "${RG}" --location "${LOCATION}" --output none
CLIENT_ID="$(az identity show --name "${DEPLOY_IDENTITY}" --resource-group "${RG}" --query clientId --output tsv)"
PRINCIPAL_ID="$(az identity show --name "${DEPLOY_IDENTITY}" --resource-group "${RG}" --query principalId --output tsv)"
TENANT_ID="$(az account show --query tenantId --output tsv)"
SUBSCRIPTION_ID="$(az account show --query id --output tsv)"

log "Identifiant fédéré : ${SUBJECT}"
if az identity federated-credential show --identity-name "${DEPLOY_IDENTITY}" --resource-group "${RG}" --name "${FED_NAME}" >/dev/null 2>&1; then
  az identity federated-credential update \
    --identity-name "${DEPLOY_IDENTITY}" \
    --resource-group "${RG}" \
    --name "${FED_NAME}" \
    --subject "${SUBJECT}" \
    --output none
else
  az identity federated-credential create \
    --identity-name "${DEPLOY_IDENTITY}" \
    --resource-group "${RG}" \
    --name "${FED_NAME}" \
    --issuer "https://token.actions.githubusercontent.com" \
    --subject "${SUBJECT}" \
    --audiences "api://AzureADTokenExchange" \
    --output none
fi

ACR_ID="$(az acr show --name "${ACR_NAME}" --query id --output tsv)"
RG_ID="$(az group show --name "${RG}" --query id --output tsv)"
log "Rôles : AcrPush sur ${ACR_NAME}, Contributor sur ${RG}"
az role assignment create --assignee-object-id "${PRINCIPAL_ID}" --assignee-principal-type ServicePrincipal --role AcrPush --scope "${ACR_ID}" --output none
az role assignment create --assignee-object-id "${PRINCIPAL_ID}" --assignee-principal-type ServicePrincipal --role Contributor --scope "${RG_ID}" --output none

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  log "Secrets GitHub (${GH_REPO}) : AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
  gh secret set AZURE_CLIENT_ID --repo "${GH_REPO}" --body "${CLIENT_ID}"
  gh secret set AZURE_TENANT_ID --repo "${GH_REPO}" --body "${TENANT_ID}"
  gh secret set AZURE_SUBSCRIPTION_ID --repo "${GH_REPO}" --body "${SUBSCRIPTION_ID}"
else
  log "gh non connecté : définir à la main les secrets AZURE_CLIENT_ID, AZURE_TENANT_ID, AZURE_SUBSCRIPTION_ID"
fi
log "Terminé."
