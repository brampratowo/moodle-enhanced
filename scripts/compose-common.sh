#!/usr/bin/env bash
# Fungsi bersama untuk install.sh, up.sh, down.sh, logs.sh
# shellcheck shell=bash

load_env_file() {
  local env_path="$1"
  local line key value

  while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%$'\r'}"
    if [[ -z "${line//[[:space:]]/}" ]]; then
      continue
    fi
    if [[ "${line}" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    key="${line%%=*}"
    value="${line#*=}"

    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    if [[ ! "${key}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      continue
    fi

    if [[ "${value}" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    elif [[ "${value}" =~ ^\'(.*)\'$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi

    export "${key}=${value}"
  done < "${env_path}"
}

build_compose_args() {
  local root_dir="$1"
  local list="${INSTALL_COMPOSE_FILES:-docker-compose-moodle.yml}"
  COMPOSE_ARGS=()
  local _sifs=$IFS
  IFS=':'
  local f p
  for f in ${list}; do
    f="${f#"${f%%[![:space:]]*}"}"
    f="${f%"${f##*[![:space:]]}"}"
    [[ -z "${f}" ]] && continue
    p="${root_dir}/${f}"
    if [[ ! -f "${p}" ]]; then
      echo "Error: berkas compose tidak ditemukan: ${p}" >&2
      exit 1
    fi
    COMPOSE_ARGS+=(-f "${p}")
  done
  IFS=${_sifs}
}

ensure_docker_network() {
  local net="${DOCKER_NETWORK_NAME:-docker_network}"
  if ! docker network inspect "${net}" >/dev/null 2>&1; then
    echo "Membuat jaringan Docker eksternal: ${net}"
    docker network create "${net}"
  fi
}

prepare_compose_bind_mounts() {
  local root_dir="$1"
  local list="${INSTALL_COMPOSE_FILES:-docker-compose-moodle.yml}"

  if [[ "${list}" == *docker-compose-mariadb.yml* ]]; then
    mkdir -p "${root_dir}/data/mariadb" "${root_dir}/config/mariadb"
    if [[ ! -f "${root_dir}/config/mariadb/my.cnf" ]]; then
      if [[ -f "${root_dir}/config/mariadb/my.cnf.example" ]]; then
        cp "${root_dir}/config/mariadb/my.cnf.example" "${root_dir}/config/mariadb/my.cnf"
        echo "Disalin config/mariadb/my.cnf.example -> config/mariadb/my.cnf (sesuaikan bila perlu)."
      else
        echo "Peringatan: config/mariadb/my.cnf tidak ada dan my.cnf.example tidak ditemukan." >&2
      fi
    fi
  fi

  if [[ "${list}" == *docker-compose-redis.yml* ]]; then
    mkdir -p "${root_dir}/config/redis"
    if [[ ! -f "${root_dir}/config/redis/redis.conf" ]]; then
      if [[ -f "${root_dir}/config/redis/redis.conf.example" ]]; then
        cp "${root_dir}/config/redis/redis.conf.example" "${root_dir}/config/redis/redis.conf"
        echo "Disalin config/redis/redis.conf.example -> config/redis/redis.conf (sesuaikan bila perlu)."
      else
        echo "Peringatan: config/redis/redis.conf tidak ada dan redis.conf.example tidak ditemukan." >&2
      fi
    fi
  fi

  if [[ "${list}" == *docker-compose-minio.yml* ]]; then
    mkdir -p "${root_dir}/data/minio" "${root_dir}/config/minio"
  fi
}
