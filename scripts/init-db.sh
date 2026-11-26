#!/usr/bin/env bash
#
# J5 — Initialise le schéma sur la base PostgreSQL distante (Neon).
# Non rejouable côté SQL (init.sql n'a pas IF NOT EXISTS) : le script refuse
# de rejouer si la table `users` existe déjà.
#
# La chaîne de connexion est un SECRET : variable DATABASE_URL de ton shell, ou
# saisie masquée. Elle n'est ni affichée, ni écrite dans un fichier.
# psql tourne dans un conteneur (postgres:16-alpine), rien à installer.

# Les commandes psql sont entre apostrophes : $DATABASE_URL doit être développé
# DANS le conteneur, pas sur l'hôte.
# shellcheck disable=SC2016
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_cmd docker

if [ -z "${DATABASE_URL:-}" ]; then
  printf "Chaîne PostgreSQL (saisie masquée) : "
  read -rs DATABASE_URL
  printf '\n'
fi
[ -n "${DATABASE_URL}" ] || die "DATABASE_URL vide"
case "${DATABASE_URL}" in
  *sslmode=require* | *sslmode=verify-full*) ;;
  *) die "la chaîne doit contenir sslmode=require (TLS obligatoire)" ;;
esac
export DATABASE_URL

# La valeur passe par l'environnement du conteneur (-e NOM sans valeur), pas par argv.
psql_run() {
  docker run --rm -i -e DATABASE_URL \
    -v "${REPO_ROOT}/database/init.sql:/init.sql:ro" \
    postgres:16-alpine sh -c "$1"
}

log "Vérification de la connexion TLS"
psql_run 'psql "$DATABASE_URL" -tAc "select version()"' | cut -c1-40

existing="$(psql_run 'psql "$DATABASE_URL" -tAc "select to_regclass('"'"'public.users'"'"') is not null"')"
if [ "${existing}" = "t" ]; then
  log "Schéma déjà présent : init.sql non rejoué (non idempotent)."
else
  log "Application de database/init.sql (une seule fois)"
  psql_run 'psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -q -f /init.sql'
fi

log "Tables :"
psql_run 'psql "$DATABASE_URL" -c "\dt"'
