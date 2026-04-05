#!/usr/bin/env bash
# Moodle + MariaDB + Redis pada satu host (beberapa berkas compose digabung).
# Jika belum ada, my.cnf / redis.conf disalin otomatis dari *.example (lihat compose-common.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INSTALL_COMPOSE_FILES="docker-compose-moodle.yml:docker-compose-mariadb.yml:docker-compose-redis.yml"
exec "${SCRIPT_DIR}/install.sh" "$@"
