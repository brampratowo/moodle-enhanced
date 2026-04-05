#!/usr/bin/env bash
# Moodle + MariaDB + Redis + MinIO pada satu host.
# my.cnf / redis.conf: disalin otomatis dari *.example jika belum ada.
# Folder data/minio dan config/minio dibuat otomatis saat instalasi.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export INSTALL_COMPOSE_FILES="docker-compose-moodle.yml:docker-compose-mariadb.yml:docker-compose-redis.yml:docker-compose-minio.yml"
exec "${SCRIPT_DIR}/install.sh" "$@"
