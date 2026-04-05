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

build_compose_args "${ROOT_DIR}"

docker compose "${COMPOSE_ARGS[@]}" logs -f --tail=200
