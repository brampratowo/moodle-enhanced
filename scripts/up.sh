#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
# shellcheck source=compose-common.sh
source "${SCRIPT_DIR}/compose-common.sh"

if [ -f "${ENV_FILE}" ]; then
  load_env_file "${ENV_FILE}"
fi

APP_HOST="${APP_HOST:-localhost}"
APP_PORT="${APP_PORT:-8080}"

build_compose_args "${ROOT_DIR}"
ensure_docker_network
prepare_compose_bind_mounts "${ROOT_DIR}"

docker compose "${COMPOSE_ARGS[@]}" up -d
echo "Container berjalan. Buka http://${APP_HOST}:${APP_PORT}"
