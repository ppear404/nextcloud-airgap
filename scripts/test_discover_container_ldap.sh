#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPLY_SCRIPT="${SCRIPT_DIR}/apply-ldap-config.sh"
PREPARE_SCRIPT="${SCRIPT_DIR}/prepare-ldap-container.sh"

if [[ -f "${APPLY_SCRIPT}" ]]; then
  # shellcheck disable=SC1090
  source "${APPLY_SCRIPT}"
fi

container="${1:-${NEXTCLOUD_APP_CONTAINER:-nextcloud-app}}"
config_id="${2:-${Configuration:-s01}}"

LDAP_CA_FILE="${LDAP_CA_FILE:-/certs/dev-rootCA.pem}"
LDAP_CA_DEST="${LDAP_CA_DEST:-/usr/local/share/ca-certificates/nextcloud-ldap-ca.crt}"

log() {
  printf '[%s] %s\n' "$(date +'%Y-%m-%dT%H:%M:%S%z')" "$*"
}

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    log "docker command not available. Install Docker or ensure it is on PATH."
    exit 1
  fi
}

ensure_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -Fxq "${container}"; then
    log "Container ${container} is not running. Start the stack before testing LDAP."
    exit 1
  fi
}

compose_ldap_uri() {
  local uri="${ldapHost}"
  local port="${ldapPort}"

  if [[ -z "${uri}" ]]; then
    log "ldapHost variable is empty; define it in apply-ldap-config.sh."
    exit 1
  fi

  if [[ -z "${port}" ]]; then
    if [[ "${uri}" =~ ^ldaps:// ]]; then
      port=636
    else
      port=389
    fi
  fi

  if [[ ! "${uri}" =~ ^ldap[s]?:// ]]; then
    local scheme="ldap"
    if [[ "${port}" == "636" ]]; then
      scheme="ldaps"
    fi
    uri="${scheme}://${uri}"
  fi

  if [[ "${uri}" != *":${port}"* ]]; then
    uri="${uri%/}:${port}"
  fi

  printf '%s' "${uri}"
}

probe_ldap_connectivity() {
  local uri
  uri="$(compose_ldap_uri)"

  read -r -d '' php_probe <<'PHP' || true
<?php
function fail(string $message, int $code): void {
    fwrite(STDERR, $message . PHP_EOL);
    exit($code);
}

$uri = getenv('LDAP_URI') ?: '';
$bindDn = getenv('LDAP_BIND_DN') ?: '';
$bindPw = getenv('LDAP_BIND_PW') ?: '';
$base = getenv('LDAP_BASE_DN') ?: '';

if ($uri === '') {
    fail('CONFIG_ERROR: Missing LDAP URI', 10);
}

$connection = ldap_connect($uri);
if (!$connection) {
    fail('CONNECT_FAIL', 11);
}

ldap_set_option($connection, LDAP_OPT_PROTOCOL_VERSION, 3);
ldap_set_option($connection, LDAP_OPT_REFERRALS, 0);

if (!@ldap_bind($connection, $bindDn, $bindPw)) {
    $error = ldap_error($connection);
    fail('BIND_FAIL: ' . $error, 12);
}

$result = @ldap_search($connection, $base, '(objectClass=*)', ['dn'], 0, 1);
if ($result === false) {
    $error = ldap_error($connection);
    fail('SEARCH_FAIL: ' . $error, 13);
}

echo "LDAP_CONNECT_OK" . PHP_EOL;
PHP

  read -r -d '' exec_cmd <<EOF || true
cat <<'PHP' >/tmp/ldap_connect_probe.php
${php_probe}
PHP
LDAPTLS_CACERT='${LDAP_CA_DEST}' LDAPTLS_REQCERT='demand' \
LDAP_URI='${uri}' \
LDAP_BIND_DN='${ldapAgentName}' \
LDAP_BIND_PW='${ldapAgentPassword}' \
LDAP_BASE_DN='${ldapBase}' \
php /tmp/ldap_connect_probe.php
EOF

  log "Validating LDAP connectivity from ${container}..."
  if ! docker exec --user www-data "${container}" bash -lc "${exec_cmd}"; then
    log "LDAP connectivity probe failed."
    return 1
  fi

  log "LDAP connectivity probe succeeded."
  return 0
}

run_occ_config_test() {
  local -a occ_cmd=(docker exec --user www-data "${container}" php occ)
  log "Running occ ldap:config-test ${config_id}..."
  if ! "${occ_cmd[@]}" ldap:config-test "${config_id}"; then
    log "occ ldap:config-test ${config_id} reported errors."
    return 1
  fi

  log "occ ldap:config-test ${config_id} completed successfully."
  return 0
}

main() {
  require_docker
  ensure_container_running

  if [[ -x "${PREPARE_SCRIPT}" ]]; then
    log "Preparing container for LDAP connectivity."
    if ! "${PREPARE_SCRIPT}" --host "${ldapHost}" --ca-file "${LDAP_CA_FILE}" "${container}"; then
      log "Container preparation reported issues."
    fi
  else
    log "Preparation script ${PREPARE_SCRIPT} not found or not executable; skipping container preparation."
  fi

  local overall_rc=0

  probe_ldap_connectivity || overall_rc=1
  run_occ_config_test || overall_rc=1

  if [[ "${overall_rc}" -ne 0 ]]; then
    log "LDAP verification completed with errors."
  else
    log "LDAP verification completed successfully."
  fi

  exit "${overall_rc}"
}

main "$@"
