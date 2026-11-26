#!/usr/bin/env bash
#
# J3 — Supprime le resource group du projet et tout ce qu'il contient
# (ACR, et plus tard les Container Apps). Action destructive et définitive :
# une confirmation tapée est exigée, aucun argument ne peut cibler un autre
# groupe que celui défini dans scripts/lib.sh.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd az
require_az_login

if ! az group show --name "${RG}" >/dev/null 2>&1; then
  log "Le resource group ${RG} n'existe pas : rien à supprimer."
  exit 0
fi

log "ATTENTION : suppression définitive du resource group ${RG}"
log "Seront supprimés : l'ACR ${ACR_NAME}, les images publiées et toutes les ressources du groupe."
log "Cette action est irréversible et asynchrone (--no-wait)."

printf "Pour confirmer, tapez le nom du groupe (%s) : " "${RG}"
read -r confirmation

if [ "${confirmation}" != "${RG}" ]; then
  die "confirmation refusée : saisie '${confirmation}' différente de '${RG}' ; rien n'a été supprimé"
fi

log "Suppression de ${RG} en cours (asynchrone)"
az group delete \
  --name "${RG}" \
  --yes \
  --no-wait

log "Demande acceptée. Vérifier ensuite : az group show -n ${RG} (doit renvoyer 'not found')."
