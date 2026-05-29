#!/usr/bin/env bash
# Stack ber-MariaDB/Redis: my.cnf / redis.conf disalin dari *.example jika belum ada (compose-common.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
ENV_EXAMPLE="${ROOT_DIR}/.env.example"
# shellcheck source=compose-common.sh
source "${SCRIPT_DIR}/compose-common.sh"

resolve_path() {
  local input_path="$1"
  if [[ "${input_path}" = /* ]]; then
    printf '%s\n' "${input_path}"
  else
    printf '%s\n' "${ROOT_DIR}/${input_path#./}"
  fi
}

write_moodle_config_php() {
  local out_path="$1"
  cat > "${out_path}" <<EOF
<?php
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype = '${DB_TYPE}';
\$CFG->dblibrary = 'native';
\$CFG->dbhost = '${DB_HOST}';
\$CFG->dbname = '${DB_NAME}';
\$CFG->dbuser = '${DB_USER}';
\$CFG->dbpass = '${DB_PASSWORD}';
\$CFG->prefix = '${DB_PREFIX}';
\$CFG->dboptions = [
  'dbpersist' => false,
  'dbsocket' => false,
  'dbport' => '${DB_PORT}',
  'dbcollation' => 'utf8mb4_unicode_ci',
];

\$CFG->wwwroot = 'http://${APP_HOST}:${APP_PORT}';
\$CFG->dataroot = '/var/www/moodledata';
\$CFG->admin = 'admin';
\$CFG->directorypermissions = 02777;

\$CFG->session_handler_class = '\\core\\session\\redis';
\$CFG->session_redis_host = '${REDIS_HOST}';
\$CFG->session_redis_port = ${REDIS_PORT};
\$CFG->session_redis_database = ${REDIS_DATABASE};
\$CFG->session_redis_prefix = '${REDIS_PREFIX}';

require_once(__DIR__ . '/lib/setup.php');
EOF
}

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker belum terpasang."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Error: docker compose plugin belum tersedia."
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "Error: curl belum terpasang."
  exit 1
fi

if ! command -v tar >/dev/null 2>&1; then
  echo "Error: tar belum terpasang."
  exit 1
fi

if [ ! -f "${ENV_FILE}" ]; then
  cp "${ENV_EXAMPLE}" "${ENV_FILE}"
  echo "File .env belum ada, dibuat dari .env.example"
fi

# Hanya memuat ${ENV_FILE} (bukan .env.example). Pastikan file .env sudah disimpan di editor.
echo "Memuat variabel dari: ${ENV_FILE}"
load_env_file "${ENV_FILE}"

MOODLEDATA_PATH="${MOODLEDATA_PATH:-./moodledata}"
MOODLE_SOURCE_PATH="${MOODLE_SOURCE_PATH:-./moodle}"
MOODLE_CONFIG_PATH="${MOODLE_CONFIG_PATH:-${MOODLE_SOURCE_PATH%/}/config.php}"
APP_HOST="${APP_HOST:-localhost}"
APP_PORT="${APP_PORT:-8080}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-3306}"
DB_TYPE="${DB_TYPE:-mariadb}"
DB_PREFIX="${DB_PREFIX:-mdl_}"

echo "Database dari .env (tanpa sandi): DB_HOST=${DB_HOST} DB_PORT=${DB_PORT} DB_NAME=${DB_NAME:-?} DB_USER=${DB_USER:-?} DB_TYPE=${DB_TYPE}"
if [ -z "${DB_NAME:-}" ] || [ -z "${DB_USER:-}" ] || [ -z "${DB_PASSWORD:-}" ]; then
  echo "Peringatan: DB_NAME, DB_USER, atau DB_PASSWORD kosong di .env. Isi di ${ENV_FILE} lalu simpan file."
fi
PERMISSION_MODE="${PERMISSION_MODE:-compat}"
WWW_DATA_UID="${WWW_DATA_UID:-33}"
WWW_DATA_GID="${WWW_DATA_GID:-33}"
MOODLE_SERIES="${MOODLE_SERIES:-}"

if [ -z "${MOODLE_SERIES}" ] && [ -n "${MOODLE_BRANCH:-}" ]; then
  if [[ "${MOODLE_BRANCH}" =~ ^MOODLE_([0-9]{3})_STABLE$ ]]; then
    MOODLE_SERIES="${BASH_REMATCH[1]}"
  fi
fi

MOODLE_SERIES="${MOODLE_SERIES:-501}"
MOODLE_DOWNLOAD_URL="${MOODLE_DOWNLOAD_URL:-https://packaging.moodle.org/stable${MOODLE_SERIES}/moodle-latest-${MOODLE_SERIES}.tgz}"

MOODLE_DIR="$(resolve_path "${MOODLE_SOURCE_PATH}")"
MOODLEDATA_HOST_PATH="$(resolve_path "${MOODLEDATA_PATH}")"
MOODLE_CONFIG_HOST_PATH="$(resolve_path "${MOODLE_CONFIG_PATH}")"

mkdir -p \
  "${MOODLE_DIR}" \
  "${MOODLEDATA_HOST_PATH}" \
  "$(dirname "${MOODLE_CONFIG_HOST_PATH}")"

# Unduh/ekstrak dulu: rm -rf moodle saat install baru akan menghapus config.php
# jika dibuat sebelum langkah ini.
if [ ! -f "${MOODLE_DIR}/version.php" ]; then
  echo "Download source Moodle resmi seri ${MOODLE_SERIES}..."
  echo "Source URL: ${MOODLE_DOWNLOAD_URL}"
  rm -rf "${MOODLE_DIR}"
  mkdir -p "${MOODLE_DIR}"
  TMP_TGZ="$(mktemp)"
  curl -fsSL "${MOODLE_DOWNLOAD_URL}" -o "${TMP_TGZ}"
  tar -xzf "${TMP_TGZ}" --strip-components=1 -C "${MOODLE_DIR}"
  rm -f "${TMP_TGZ}"
else
  echo "Source Moodle sudah ada, skip download."
fi

# Paket Moodle tidak menyertakan config.php (hanya config-dist.php). File ini dibuat dari .env
# setelah source diekstrak. Sinkron ulang setiap install.sh agar .env dan config.php selaras.
# Set MOODLE_CONFIG_SKIP_SYNC=1 di .env bila ingin mempertahankan config.php yang diedit manual.
if [ "${MOODLE_CONFIG_SKIP_SYNC:-0}" = "1" ] && [ -f "${MOODLE_CONFIG_HOST_PATH}" ]; then
  echo "MOODLE_CONFIG_SKIP_SYNC=1: mempertahankan ${MOODLE_CONFIG_HOST_PATH}."
else
  if [ -f "${MOODLE_CONFIG_HOST_PATH}" ]; then
    echo "Menulis ulang ${MOODLE_CONFIG_HOST_PATH} dari .env."
  else
    echo "Membuat ${MOODLE_CONFIG_HOST_PATH} dari .env (file ini tidak ada di arsip Moodle resmi)."
  fi
  write_moodle_config_php "${MOODLE_CONFIG_HOST_PATH}"
fi

apply_compat_permissions() {
  echo "Mode permission: compat (paling longgar untuk kompatibilitas)."
  chmod -R 777 "${MOODLEDATA_HOST_PATH}" 2>/dev/null || true
  chmod 666 "${MOODLE_CONFIG_HOST_PATH}" 2>/dev/null || true
}

apply_prod_permissions_docker() {
  local container="${1:-moodle-app}"
  local host_uid host_gid
  if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "${container}"; then
    return 1
  fi
  host_uid="$(id -u)"
  host_gid="$(id -g)"
  echo "Menerapkan permission ${PERMISSION_MODE} via container ${container}..."
  docker exec -u root "${container}" chown -R "${host_uid}:${host_gid}" /var/www/html
  docker exec -u root "${container}" chown www-data:www-data /var/www/html/config.php
  docker exec -u root "${container}" chown -R www-data:www-data /var/www/moodledata
  docker exec -u root "${container}" chmod 660 /var/www/html/config.php
  docker exec -u root "${container}" chmod -R 770 /var/www/moodledata
}

if [[ "${PERMISSION_MODE}" = "prod" || "${PERMISSION_MODE}" = "secure" ]]; then
  echo "Mode permission: ${PERMISSION_MODE} (config.php + moodledata; source Moodle tidak diubah)."
else
  apply_compat_permissions
fi

build_compose_args "${ROOT_DIR}"
echo "Stack Compose (INSTALL_COMPOSE_FILES): ${INSTALL_COMPOSE_FILES:-docker-compose-moodle.yml}"

ensure_docker_network
prepare_compose_bind_mounts "${ROOT_DIR}"

echo "Build image Moodle (app, cron)..."
docker compose "${COMPOSE_ARGS[@]}" build app cron

echo "Menjalankan stack..."
docker compose "${COMPOSE_ARGS[@]}" up -d

if [[ "${PERMISSION_MODE}" = "prod" || "${PERMISSION_MODE}" = "secure" ]]; then
  if ! apply_prod_permissions_docker moodle-app; then
    echo "Peringatan: permission prod belum diterapkan (container moodle-app belum siap)."
    echo "  Jalankan setelah stack jalan:"
    echo "  docker exec -u root moodle-app chown www-data:www-data /var/www/html/config.php"
    echo "  docker exec -u root moodle-app chown -R www-data:www-data /var/www/moodledata"
    echo "  docker exec -u root moodle-app chmod 660 /var/www/html/config.php"
    echo "  docker exec -u root moodle-app chmod -R 770 /var/www/moodledata"
  fi
fi

echo
echo "Selesai. Lanjutkan instalasi Moodle via browser:"
echo "http://${APP_HOST}:${APP_PORT}"
echo
echo "Database setting di wizard Moodle:"
echo "- Host: ${DB_HOST}"
echo "- Port: ${DB_PORT}"
echo "- Name: ${DB_NAME}"
echo "- User: ${DB_USER}"
echo "- Password: ${DB_PASSWORD}"
