#!/usr/bin/env bash
set -euo pipefail

# prepare-hosts-pi3.sh
# Creates host directories required by docker-compose.pi3.yml
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
if [[ -f ./.env.pi3 ]]; then
  # shellcheck disable=SC1091
  set -o allexport; source ./.env.pi3; set +o allexport
fi

# Defaults
PI3_COMPOSE_DIR=${PI3_COMPOSE_DIR:-$HOME/docker}
GATUS_CONFIG_DIR=${GATUS_CONFIG_DIR:-$PI3_COMPOSE_DIR/gatus}
USB_MOUNT=${USB_MOUNT:-/mnt/usb}

APP_USER_ID=${APP_USER_ID:-1000}
APP_GROUP_ID=${APP_GROUP_ID:-1000}

# Directories to ensure exist
dirs=(
  "$PI3_COMPOSE_DIR"
  "$GATUS_CONFIG_DIR"
  "$USB_MOUNT"
)

printf "Will ensure the following directories exist on Pi3:\n"
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
  printf "chown %s:%s '%s'\n" "$APP_USER_ID" "$APP_GROUP_ID" "$d"
  sudo chown -R "$APP_USER_ID":"$APP_GROUP_ID" "$d" || true
done

printf "\nPi3 host preparation complete.\n"
printf "Tip: copy .env.common and docker-compose.pi3.yml to the Pi3 and verify PI3_IP in traefik/dynamic/dynamic_pi3.yml.\n"
