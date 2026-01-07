#!/usr/bin/env bash
set -euo pipefail

# prepare-hosts-optiplex.sh
# Creates host directories required by docker-compose.optiplex.yml
# Dry-run by default. Use --apply to actually create and chown.

APPLY=0
if [[ "${1:-}" == "--apply" ]]; then
  APPLY=1
fi

# Load env files if present (export variables)
if [[ -f ./.env.common ]]; then
  # shellcheck disable=SC1091
  set -o allexport; source ./.env.common; set +o allexport
fi
if [[ -f ./.env.optiplex ]]; then
  # shellcheck disable=SC1091
  set -o allexport; source ./.env.optiplex; set +o allexport
fi

# Defaults (fallbacks)
BOOKDATA_PATH=${BOOKDATA_PATH:-/mnt/2tb/bookdata}
UPLOAD_LOCATION=${UPLOAD_LOCATION:-./volumes/immich/upload}
DB_DATA_LOCATION=${DB_DATA_LOCATION:-./volumes/immich-db}
PAPERLESS_DATA_DIR=${PAPERLESS_DATA_DIR:-./volumes/paperless/data}
PAPERLESS_MEDIA_DIR=${PAPERLESS_MEDIA_DIR:-./volumes/paperless/media}
PAPERLESS_EXPORT_DIR=${PAPERLESS_EXPORT_DIR:-./volumes/paperless/export}
MARIADB_CONFIG_DIR=${MARIADB_CONFIG_DIR:-./mariadb/config}
TRAEFIK_DYNAMIC_DIR=${TRAEFIK_DYNAMIC_DIR:-./traefik/dynamic}
HEADSCALE_DIR=${HEADSCALE_DIR:-./headscale}
GIT_REPO_ROOT=$(pwd)

# Ownership defaults
APP_USER_ID=${APP_USER_ID:-1000}
APP_GROUP_ID=${APP_GROUP_ID:-1000}

# Directories to ensure exist (ordered)
dirs=(
  "$TRAEFIK_DYNAMIC_DIR"
  "$HEADSCALE_DIR"
  "$PAPERLESS_DATA_DIR"
  "$PAPERLESS_MEDIA_DIR"
  "$PAPERLESS_EXPORT_DIR"
  "$MARIADB_CONFIG_DIR"
  "$UPLOAD_LOCATION"
  "$DB_DATA_LOCATION"
  "$BOOKDATA_PATH/books"
  "$BOOKDATA_PATH/bookdrop"
)

printf "Will ensure the following directories exist on Optiplex:\n"
for d in "${dirs[@]}"; do
  printf "  - %s\n" "$d"
done

printf "\nOwnership will be set to UID:GID = %s:%s\n" "$APP_USER_ID" "$APP_GROUP_ID"

if [[ $APPLY -eq 0 ]]; then
  printf "\nDRY RUN (no changes made). To create and chown, re-run with --apply\n"
  exit 0
fi

printf "\nCreating directories and applying ownership...\n"
for d in "${dirs[@]}"; do
  if [[ ! -d "$d" ]]; then
    printf "mkdir -p '%s'\n" "$d"
    mkdir -p "$d"
  else
    printf "exists: '%s'\n" "$d"
  fi
  # chown
  printf "chown %s:%s '%s'\n" "$APP_USER_ID" "$APP_GROUP_ID" "$d"
  sudo chown -R "$APP_USER_ID":"$APP_GROUP_ID" "$d" || true
done

printf "\nOptiplex host preparation complete.\n"
printf "Tip: ensure ./headscale/config.yaml and ./traefik/dynamic/dynamic_pi3.yml contain correct values.\n"
