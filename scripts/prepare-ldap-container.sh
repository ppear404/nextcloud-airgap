#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY_SCRIPT="${SCRIPT_DIR}/apply-ldap-config.sh"

if [[ -f "${APPLY_SCRIPT}" ]]; then
  # shellcheck disable=SC1090
  source "${APPLY_SCRIPT}"
fi

container="${1:-${NEXTCLOUD_APP_CONTAINER:-nextcloud-app}}"

LDAP_CA_FILE="${LDAP_CA_FILE:-/certs/dev-rootCA.pem}"
LDAP_CA_DEST="${LDAP_CA_DEST:-/usr/local/share/ca-certificates/nextcloud-ldap-ca.crt}"
LDAP_HOST="${LDAP_HOST:-${ldapHost}}"
LDAP_HOST_IP="${LDAP_HOST_IP:-}"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$*"
}

usage() {
  cat <<'EOF'
Usage: prepare-ldap-container.sh [options] [container]

Prepares the Nextcloud container for LDAPS by installing the trusted root CA
and ensuring name resolution for the LDAP host. Run this before applying or
testing LDAP configuration.

Options:
  --host HOSTNAME   Override LDAP host (default: value from apply-ldap-config.sh)
  --ip ADDRESS      Explicit IP address for LDAP host (otherwise resolved)
  --ca-file PATH    Root CA PEM to install (default: ./certs/dev-rootCA.pem)
  --ca-dest PATH    Path inside container to place CA (default: /usr/local/share/ca-certificates/nextcloud-ldap-ca.crt)
  -h, --help        Display help
EOF
}

strip_scheme() {
  local value="$1"
  value="${value#ldap://}"
  value="${value#ldaps://}"
  echo "${value}"
}

resolve_host_ip() {
  local host="$1"
  local ip=""
  if command -v getent >/dev/null 2>&1; then
    ip="$(getent ahostsv4 "${host}" | awk 'NR==1 {print $1}')"
  fi
  echo "${ip}"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log "docker command not available. Install Docker or ensure it is on PATH."
    exit 1
  fi
}

ensure_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -Fxq "${container}"; then
    log "Container ${container} is not running. Start the stack before preparing."
    exit 1
  fi
}

install_ca_certificate() {
  if [[ -z "${LDAP_CA_FILE}" ]]; then
    log "LDAP_CA_FILE not set; skipping CA installation."
    return 0
  fi

  if ! docker exec --user root "${container}" test -f "${LDAP_CA_FILE}"; then
    log "LDAP CA file ${LDAP_CA_FILE} not present inside ${container}; skipping trust store update."
    return 0
  fi

  if docker exec --user root "${container}" bash -lc "[[ -f '${LDAP_CA_DEST}' ]] && cmp -s '${LDAP_CA_FILE}' '${LDAP_CA_DEST}'"; then
    log "LDAP CA certificate already installed in ${container}."
    return 0
  fi

  log "Installing LDAP CA certificate from ${LDAP_CA_FILE} into ${container}."
  if ! docker exec --user root "${container}" bash -lc "cp '${LDAP_CA_FILE}' '${LDAP_CA_DEST}' && chmod 644 '${LDAP_CA_DEST}' && update-ca-certificates >/dev/null"; then
    log "Failed to install LDAP CA certificate into ${container}."
    return 1
  fi

  local ldap_conf="/etc/ldap/ldap.conf"
  docker exec --user root "${container}" bash -lc "grep -q \"^TLS_CACERT ${LDAP_CA_DEST//\//\\/}\$\" '${ldap_conf}' 2>/dev/null || echo 'TLS_CACERT ${LDAP_CA_DEST}' >> '${ldap_conf}'"
  docker exec --user root "${container}" bash -lc "grep -q '^TLS_REQCERT' '${ldap_conf}' 2>/dev/null || echo 'TLS_REQCERT demand' >> '${ldap_conf}'"

  log "LDAP CA certificate installed in ${container}."
  return 0
}

update_hosts_entry() {
  local host="$1"
  local ip="$2"

  if [[ -z "${host}" ]]; then
    log "LDAP host not provided; skipping /etc/hosts update."
    return 0
  fi

  if [[ -z "${ip}" ]]; then
    log "No IP address resolved for ${host}; skipping /etc/hosts update."
    return 0
  fi

  local hosts_file="/etc/hosts"
  local sanitized_host
  sanitized_host="$(strip_scheme "${host}")"

  if docker exec --user root "${container}" grep -qE "^[0-9.]+\s+${sanitized_host}(\\s|$)" "${hosts_file}"; then
    if docker exec --user root "${container}" grep -qE "^${ip//./\\.}\\s+${sanitized_host}(\\s|$)" "${hosts_file}"; then
      log "/etc/hosts already contains ${sanitized_host} -> ${ip}."
      return 0
    fi
    log "Updating existing host entry for ${sanitized_host} to ${ip}."
    docker exec --user root "${container}" bash -lc "tmp=\$(mktemp) && awk '!/\\s${sanitized_host//./\\.}(\\s|$)/ {print}' '${hosts_file}' >\"\$tmp\" && printf '%s %s\\n' '${ip}' '${sanitized_host}' >>\"\$tmp\" && cat \"\$tmp\" >'${hosts_file}' && rm \"\$tmp\""
  else
    log "Adding ${sanitized_host} -> ${ip} to /etc/hosts."
    docker exec --user root "${container}" bash -lc "printf '%s %s\\n' '${ip}' '${sanitized_host}' >> '${hosts_file}'"
  fi

  return 0
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        LDAP_HOST="$2"; shift 2;;
      --ip)
        LDAP_HOST_IP="$2"; shift 2;;
      --ca-file)
        LDAP_CA_FILE="$2"; shift 2;;
      --ca-dest)
        LDAP_CA_DEST="$2"; shift 2;;
      -h|--help)
        usage; exit 0;;
      -*)
        echo "Unknown option: $1" >&2
        usage
        exit 1;;
      *)
        container="$1"; shift;;
    esac
  done

  LDAP_HOST="$(strip_scheme "${LDAP_HOST}")"

  if [[ -z "${LDAP_HOST_IP}" ]]; then
    LDAP_HOST_IP="$(resolve_host_ip "${LDAP_HOST}")"
  fi

  require_docker
  ensure_container_running

  log "Preparing container ${container} for LDAP connectivity."
  log "Using LDAP host ${LDAP_HOST}${LDAP_HOST_IP:+ (${LDAP_HOST_IP})}"

  install_ca_certificate
  update_hosts_entry "${LDAP_HOST}" "${LDAP_HOST_IP}"

  log "Preparation complete."
}

main "$@"
