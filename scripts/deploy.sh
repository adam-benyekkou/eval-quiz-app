#!/usr/bin/env bash
#
# J3/J4 — Crée le resource group et l'ACR, publie les images avec un tag
# traçable (SHA court du commit), puis déploie le backend et le frontend dans
# Azure Container Apps. Idempotent : relançable sans échec.
#
# Usage :
#   scripts/deploy.sh               build local (Docker) + docker push
#   scripts/deploy.sh --acr-build   build déporté dans ACR (az acr build)
#   scripts/deploy.sh --skip-build  réutilise quiz-{backend,frontend}:local
#
# Aucun secret n'est stocké ni affiché : `az login` fournit l'authentification,
# l'admin user du registre reste désactivé.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

MODE="local"
SKIP_BUILD=false

usage() {
  cat <<'EOF'
Usage: scripts/deploy.sh [--acr-build | --skip-build]

  --acr-build   construire les images dans ACR (aucun démon Docker requis)
  --skip-build  ne pas reconstruire, réutiliser les images locales
  -h, --help    afficher cette aide

Variables surchargeables : RG, LOCATION, ACR_NAME, TAG (voir scripts/lib.sh).
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --acr-build) MODE="acr" ;;
    --skip-build) SKIP_BUILD=true ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) die "option inconnue : $1 (voir --help)" ;;
  esac
  shift
done

if [ "${MODE}" = "acr" ] && [ "${SKIP_BUILD}" = true ]; then
  die "--acr-build et --skip-build sont incompatibles"
fi

require_cmd az
require_az_login
if [ "${MODE}" = "local" ]; then
  require_cmd docker
fi

log "Cible : RG=${RG} LOCATION=${LOCATION} ACR=${ACR_NAME} TAG=${TAG}"

# --- Étape 1 : resource group (idempotent) ---------------------------------
log "Création/vérification du resource group ${RG} (${LOCATION})"
az group create \
  --name "${RG}" \
  --location "${LOCATION}" \
  --output none
log "OK resource group ${RG}"

# --- Étape 2 : ACR Basic, admin user désactivé (idempotent) ----------------
log "Création/vérification de l'ACR ${ACR_NAME} (sku Basic, admin user désactivé)"
az acr create \
  --name "${ACR_NAME}" \
  --resource-group "${RG}" \
  --sku Basic \
  --admin-enabled false \
  --output none
log "OK ACR ${ACR_NAME} (${LOGIN_SERVER})"

# --- Étape 3 : build et publication des deux images ------------------------
if [ "${MODE}" = "acr" ]; then
  log "Build déporté : ${IMAGE_BACKEND}:${TAG} (contexte backend/)"
  az acr build \
    --registry "${ACR_NAME}" \
    --image "${IMAGE_BACKEND}:${TAG}" \
    --file "${REPO_ROOT}/backend/Dockerfile" \
    "${REPO_ROOT}/backend" \
    --output none

  log "Build déporté : ${IMAGE_FRONTEND}:${TAG} (contexte racine)"
  az acr build \
    --registry "${ACR_NAME}" \
    --image "${IMAGE_FRONTEND}:${TAG}" \
    --file "${REPO_ROOT}/Dockerfile" \
    "${REPO_ROOT}" \
    --output none
else
  if [ "${SKIP_BUILD}" = false ]; then
    log "Build local : ${IMAGE_BACKEND}:local (contexte backend/)"
    docker build --tag "${IMAGE_BACKEND}:local" "${REPO_ROOT}/backend"

    log "Build local : ${IMAGE_FRONTEND}:local (contexte racine)"
    docker build --tag "${IMAGE_FRONTEND}:local" "${REPO_ROOT}"
  fi

  docker image inspect "${IMAGE_BACKEND}:local" >/dev/null 2>&1 ||
    die "image ${IMAGE_BACKEND}:local absente : relancer sans --skip-build"
  docker image inspect "${IMAGE_FRONTEND}:local" >/dev/null 2>&1 ||
    die "image ${IMAGE_FRONTEND}:local absente : relancer sans --skip-build"

  log "Connexion Docker à ${LOGIN_SERVER} (jeton Azure AD, pas de mot de passe)"
  az acr login --name "${ACR_NAME}" --output none

  for image in "${IMAGE_BACKEND}" "${IMAGE_FRONTEND}"; do
    log "Tag et push ${LOGIN_SERVER}/${image}:${TAG}"
    docker tag "${image}:local" "${LOGIN_SERVER}/${image}:${TAG}"
    docker push "${LOGIN_SERVER}/${image}:${TAG}"
  done
fi

# --- Étape 4 : preuve de publication ---------------------------------------
log "Dépôts présents dans ${ACR_NAME} :"
az acr repository list --name "${ACR_NAME}" --output table
for repo in "${IMAGE_BACKEND}" "${IMAGE_FRONTEND}"; do
  log "Tags de ${repo} :"
  az acr repository show-tags \
    --name "${ACR_NAME}" \
    --repository "${repo}" \
    --orderby time_desc \
    --output table
done

# --- J4 : environnement Container Apps, identité de pull, deux apps ---------
# Constat : l'abonnement ne crée que des environnements « express » (pas de DNS
# interne, pas de HTTP clair, pas d'identité système). Le backend est donc joint
# par son URL publique (HTTPS) et protégé par une restriction d'IP.
MIN_REPLICAS="${MIN_REPLICAS:-1}"
FROM_EMAIL="${FROM_EMAIL:-Quiz App <noreply@notifications.labformation.fr>}"
ADMIN_USERNAME="${ADMIN_USERNAME:-admin}"

app_exists() {
  az containerapp show --name "$1" --resource-group "${RG}" >/dev/null 2>&1
}

log "Environnement Container Apps ${ENV_NAME}"
if ! az containerapp env show --name "${ENV_NAME}" --resource-group "${RG}" >/dev/null 2>&1; then
  az containerapp env create \
    --name "${ENV_NAME}" \
    --resource-group "${RG}" \
    --location "${LOCATION}" \
    --output none
fi
log "OK environnement ${ENV_NAME}"

log "Identité managée de pull ${PULL_IDENTITY} (AcrPull sur ${ACR_NAME})"
az identity create \
  --name "${PULL_IDENTITY}" \
  --resource-group "${RG}" \
  --location "${LOCATION}" \
  --output none
PULL_ID="$(az identity show --name "${PULL_IDENTITY}" --resource-group "${RG}" --query id --output tsv)"
PULL_PRINCIPAL="$(az identity show --name "${PULL_IDENTITY}" --resource-group "${RG}" --query principalId --output tsv)"
ACR_ID="$(az acr show --name "${ACR_NAME}" --query id --output tsv)"
az role assignment create \
  --assignee-object-id "${PULL_PRINCIPAL}" \
  --assignee-principal-type ServicePrincipal \
  --role AcrPull \
  --scope "${ACR_ID}" \
  --output none

# Secrets : fournis par l'environnement ; sinon générés (jamais affichés,
# jamais écrits dans un fichier). Utilisés uniquement à la création de l'app.
JWT_SECRET="${JWT_SECRET:-$(openssl rand -hex 32)}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-$(openssl rand -hex 16)}"
RESEND_API_KEY="${RESEND_API_KEY:-re_placeholder_not_real}"

BACKEND_IMAGE="${LOGIN_SERVER}/${IMAGE_BACKEND}:${TAG}"
FRONTEND_IMAGE="${LOGIN_SERVER}/${IMAGE_FRONTEND}:${TAG}"

log "Backend ${BACKEND_APP} : ${BACKEND_IMAGE}"
if app_exists "${BACKEND_APP}"; then
  az containerapp update \
    --name "${BACKEND_APP}" \
    --resource-group "${RG}" \
    --image "${BACKEND_IMAGE}" \
    --min-replicas "${MIN_REPLICAS}" \
    --max-replicas 1 \
    --output none
else
  az containerapp create \
    --name "${BACKEND_APP}" \
    --resource-group "${RG}" \
    --environment "${ENV_NAME}" \
    --image "${BACKEND_IMAGE}" \
    --target-port 3007 \
    --ingress external \
    --min-replicas "${MIN_REPLICAS}" \
    --max-replicas 1 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --user-assigned "${PULL_ID}" \
    --registry-server "${LOGIN_SERVER}" \
    --registry-identity "${PULL_ID}" \
    --secrets "jwt-secret=${JWT_SECRET}" "admin-password=${ADMIN_PASSWORD}" "resend-api-key=${RESEND_API_KEY}" \
    --env-vars PORT=3007 "FROM_EMAIL=${FROM_EMAIL}" "ADMIN_USERNAME=${ADMIN_USERNAME}" \
      JWT_SECRET=secretref:jwt-secret ADMIN_PASSWORD=secretref:admin-password RESEND_API_KEY=secretref:resend-api-key \
    --output none
fi
BACKEND_FQDN="$(az containerapp show --name "${BACKEND_APP}" --resource-group "${RG}" --query properties.configuration.ingress.fqdn --output tsv)"
log "OK backend https://${BACKEND_FQDN}"

log "Frontend ${FRONTEND_APP} : ${FRONTEND_IMAGE}"
if app_exists "${FRONTEND_APP}"; then
  az containerapp update \
    --name "${FRONTEND_APP}" \
    --resource-group "${RG}" \
    --image "${FRONTEND_IMAGE}" \
    --min-replicas "${MIN_REPLICAS}" \
    --max-replicas 1 \
    --set-env-vars BACKEND_SCHEME=https "BACKEND_HOST=${BACKEND_FQDN}" BACKEND_PORT=443 \
    --output none
else
  az containerapp create \
    --name "${FRONTEND_APP}" \
    --resource-group "${RG}" \
    --environment "${ENV_NAME}" \
    --image "${FRONTEND_IMAGE}" \
    --target-port 8080 \
    --ingress external \
    --min-replicas "${MIN_REPLICAS}" \
    --max-replicas 1 \
    --cpu 0.25 \
    --memory 0.5Gi \
    --user-assigned "${PULL_ID}" \
    --registry-server "${LOGIN_SERVER}" \
    --registry-identity "${PULL_ID}" \
    --env-vars BACKEND_SCHEME=https "BACKEND_HOST=${BACKEND_FQDN}" BACKEND_PORT=443 \
    --output none
fi
FRONTEND_FQDN="$(az containerapp show --name "${FRONTEND_APP}" --resource-group "${RG}" --query properties.configuration.ingress.fqdn --output tsv)"
log "OK frontend https://${FRONTEND_FQDN}"

# Restriction d'accès : seul le frontend (ses IP sortantes) devrait appeler le
# backend. En environnement express, l'API n'expose pas ces IP (constaté :
# outboundIpAddresses = null) : on n'invente pas de règle, on le signale.
FRONTEND_IPS="$(az containerapp show --name "${FRONTEND_APP}" --resource-group "${RG}" --query "properties.outboundIpAddresses" --output tsv 2>/dev/null || true)"
if [ -n "${FRONTEND_IPS}" ] && [ "${FRONTEND_IPS}" != "None" ]; then
  n=0
  for ip in ${FRONTEND_IPS}; do
    n=$((n + 1))
    az containerapp ingress access-restriction set \
      --name "${BACKEND_APP}" \
      --resource-group "${RG}" \
      --rule-name "allow-frontend-${n}" \
      --ip-address "${ip}/32" \
      --action Allow \
      --output none
  done
  log "OK ${n} IP autorisée(s) sur le backend"
else
  log "ATTENTION : IP sortantes du frontend non exposées (environnement express) ; backend joignable publiquement, protégé par l'authentification applicative seulement"
fi

log "Révisions :"
az containerapp revision list --name "${BACKEND_APP}" --resource-group "${RG}" --output table
az containerapp revision list --name "${FRONTEND_APP}" --resource-group "${RG}" --output table

log "Terminé. Frontend : https://${FRONTEND_FQDN} (test : curl -i https://${FRONTEND_FQDN}/health)"
