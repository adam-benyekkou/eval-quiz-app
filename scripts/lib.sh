#!/usr/bin/env bash
#
# Configuration et fonctions partagées des scripts Azure.
# Aucun secret ici : l'authentification vient de `az login` ou de l'environnement.
# Sourcé par deploy.sh et destroy.sh, jamais exécuté directement.

# Les constantes ci-dessous sont consommées par les scripts appelants.
# shellcheck disable=SC2034

# Garde-fou : un `source` depuis un script sans `set -euo pipefail` hérite des options.
set -euo pipefail

# --- Noms du projet : source unique de vérité -------------------------------
# Surchargeables par variable d'environnement pour un test jetable.
RG="${RG:-rg-quiz-eval}"
LOCATION="${LOCATION:-francecentral}"
ACR_NAME="${ACR_NAME:-acrquizevaladam}"
ENV_NAME="${ENV_NAME:-cae-quiz-eval}"

PULL_IDENTITY="${PULL_IDENTITY:-id-quiz-acr-pull}"
BACKEND_APP="${BACKEND_APP:-backend}"
FRONTEND_APP="${FRONTEND_APP:-frontend}"

IMAGE_BACKEND="quiz-backend"
IMAGE_FRONTEND="quiz-frontend"
LOGIN_SERVER="${ACR_NAME}.azurecr.io"

# Tag traçable : SHA court du commit. Jamais `latest` seul.
TAG="${TAG:-$(git -C "$(dirname "${BASH_SOURCE[0]}")/.." rev-parse --short HEAD 2>/dev/null || echo local)}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Sortie ----------------------------------------------------------------
log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

die() {
  printf '[erreur] %s\n' "$*" >&2
  exit 1
}

# --- Prérequis -------------------------------------------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "commande requise introuvable : $1"
}

require_az_login() {
  az account show >/dev/null 2>&1 ||
    die "non connecté à Azure : lancer 'az login' (aucun identifiant n'est stocké dans le dépôt)"
}
