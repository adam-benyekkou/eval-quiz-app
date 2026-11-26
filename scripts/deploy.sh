#!/usr/bin/env bash
#
# J3 — Crée le resource group et l'ACR, puis publie les images avec un tag
# traçable (SHA court du commit). Idempotent : relançable sans échec.
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

log "Terminé. Images publiées : ${LOGIN_SERVER}/${IMAGE_BACKEND}:${TAG} et ${LOGIN_SERVER}/${IMAGE_FRONTEND}:${TAG}"
