#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."

# Defaults that match the current development environment.
LDAP_URI="${LDAP_URI:-ldaps://dc1.1233lab.local:636}"
LDAP_BIND_DN="${LDAP_BIND_DN:-ldap_bind@1233lab.local}"
LDAP_BIND_PW="${LDAP_BIND_PW:-simple123P@ss}"
LDAP_BASE_DN="${LDAP_BASE_DN:-dc=1233lab,dc=local}"
LDAP_PAGE_SIZE="${LDAP_PAGE_SIZE:-50}"
LDAP_CA_FILE_DEFAULT="${REPO_ROOT}/certs/dev-rootCA.pem"
LDAP_CA_FILE="${LDAP_CA_FILE:-${LDAP_CA_FILE_DEFAULT}}"

usage() {
  cat <<'EOF'
Usage: enum_ldap.sh [options]

Enumerate Active Directory objects from the host (no container exec). Helpful
for discovering attributes needed when wiring LDAP into Nextcloud later.

Options:
  --uri URI             LDAP URI (default: ldaps://dc1.1233lab.local:636)
  --bind-dn DN          Bind DN / user (default: ldap_bind@1233lab.local)
  --bind-pw PASSWORD    Bind password (default: simple123P@ss)
  --base-dn DN          Base DN for searches (default: dc=1233lab,dc=local)
  --page-size N         Paged result size (default: 50)
  --ca-file PATH        PEM file for the LDAP server CA
  -h, --help            Show this help

Environment variables LDAP_URI, LDAP_BIND_DN, LDAP_BIND_PW, LDAP_BASE_DN,
LDAP_PAGE_SIZE, LDAP_CA_FILE may also be used.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uri)
      LDAP_URI="$2"; shift 2;;
    --bind-dn)
      LDAP_BIND_DN="$2"; shift 2;;
    --bind-pw)
      LDAP_BIND_PW="$2"; shift 2;;
    --base-dn)
      LDAP_BASE_DN="$2"; shift 2;;
    --page-size)
      LDAP_PAGE_SIZE="$2"; shift 2;;
    --ca-file)
      LDAP_CA_FILE="$2"; shift 2;;
    -h|--help)
      usage; exit 0;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! command -v ldapsearch >/dev/null 2>&1; then
  echo "ldapsearch command not found. Install ldap-utils (Debian/Ubuntu) or openldap-clients (RHEL/CentOS)." >&2
  exit 1
fi

if [[ -n "${LDAP_CA_FILE}" && ! -f "${LDAP_CA_FILE}" ]]; then
  echo "Warning: LDAP CA file ${LDAP_CA_FILE} not found; proceeding without TLS verification override." >&2
  LDAP_CA_FILE=""
fi

LDAPSEARCH_OPTS=(-LLL -o ldif-wrap=no -x -H "${LDAP_URI}" -D "${LDAP_BIND_DN}" -w "${LDAP_BIND_PW}")

if [[ -n "${LDAP_CA_FILE}" ]]; then
  export LDAPTLS_CACERT="${LDAP_CA_FILE}"
  export LDAPTLS_REQCERT=demand
fi

print_section() {
  local title="$1"
  echo
  echo "================================================================================"
  echo "${title}"
  echo "================================================================================"
}

run_search() {
  local base="$1"
  local scope="$2"
  local filter="$3"
  shift 3
  local attrs=("$@")

  ldapsearch "${LDAPSEARCH_OPTS[@]}" -b "${base}" -s "${scope}" -z "${LDAP_PAGE_SIZE}" "${filter}" "${attrs[@]}"
}

print_section "Root DSE – naming contexts and capabilities"
run_search "" base "(objectClass=*)" namingContexts defaultNamingContext configurationNamingContext schemaNamingContext supportedLDAPVersion supportedSASLMechanisms subschemaSubentry vendorName vendorVersion || true

print_section "Domain summary (${LDAP_BASE_DN})"
run_search "${LDAP_BASE_DN}" base "(objectClass=*)" defaultNamingContext dcObject objectClass msDS-Behavior-Version || true

print_section "Sample users (first ${LDAP_PAGE_SIZE})"
run_search "${LDAP_BASE_DN}" sub "(&(objectClass=user)(objectCategory=person))" dn sAMAccountName userPrincipalName displayName mail memberOf whenCreated whenChanged || true

print_section "Sample groups (first ${LDAP_PAGE_SIZE})"
run_search "${LDAP_BASE_DN}" sub "(objectClass=group)" dn sAMAccountName cn member memberOf groupType || true

print_section "Schema references"
run_search "" base "(objectClass=*)" subschemaSubentry || true

print_section "OID configuration (schema CN)"
# Query the schema naming context to enumerate attribute definitions.
SCHEMA_BASE="$(run_search "" base "(objectClass=*)" schemaNamingContext | awk -F': ' '/^schemaNamingContext:/ {print $2; exit}')"
if [[ -n "${SCHEMA_BASE}" ]]; then
  run_search "${SCHEMA_BASE}" one "(objectClass=*)" cn objectClass || true
else
  echo "Schema naming context not discovered; skipping schema enumeration." >&2
fi

echo
echo "Enumeration complete. Use the results above to choose appropriate LDAP attributes for Nextcloud."
