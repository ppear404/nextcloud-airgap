#!/bin/bash
set -euo pipefail

CERT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)/certs
CSR_CONFIG="${CERT_DIR}/nextcloud-dev.cnf"
CA_KEY="${CERT_DIR}/dev-rootCA.key"
CA_CERT="${CERT_DIR}/dev-rootCA.pem"
CA_SERIAL="${CERT_DIR}/dev-rootCA.srl"
CERT_KEY="${CERT_DIR}/nextcloud-dev-key.pem"
CERT_FILE="${CERT_DIR}/nextcloud-dev.pem"
BUNDLE="${CERT_DIR}/custom-ca-bundle.pem"
FORCE=false

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--force]

Generates a development TLS certificate for nextcloud-dev.lan and nextcloud-dev.
Outputs are written into ${CERT_DIR}:
  - dev-rootCA.key / dev-rootCA.pem : development CA used for signing
  - nextcloud-dev-key.pem / nextcloud-dev.pem : server key and certificate (PEM with chain)
The CA certificate is appended to custom-ca-bundle.pem when missing.

Options:
  --force   Regenerate the server key and certificate even if one already exists.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

mkdir -p "${CERT_DIR}"

if [[ ! -f "${CSR_CONFIG}" ]]; then
  cat >"${CSR_CONFIG}" <<'CFG'
[ req ]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn

[ dn ]
C = US
ST = Dev
L = Dev
O = Nextcloud Development
OU = Local
CN = nextcloud-dev.lan

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = nextcloud-dev.lan
DNS.2 = nextcloud-dev
CFG
fi

ensure_ca() {
  if [[ ! -f "${CA_KEY}" || ! -f "${CA_CERT}" ]]; then
    echo "[ensure-nextcloud-cert] Generating development root CA"
    openssl genrsa -out "${CA_KEY}" 4096 >/dev/null 2>&1
    openssl req -x509 -new -key "${CA_KEY}" -out "${CA_CERT}" \
      -days 3650 -sha256 \
      -subj "/C=US/ST=Dev/L=Dev/O=Nextcloud Development CA/OU=Local/CN=Nextcloud Dev Root" >/dev/null 2>&1
    rm -f "${CA_SERIAL}"
  fi
}

cert_has_san() {
  [[ -f "${CERT_FILE}" ]] || return 1
  openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName 2>/dev/null | grep -q "nextcloud-dev.lan"
}

ensure_cert() {
  if [[ "${FORCE}" == true ]] || ! cert_has_san; then
    echo "[ensure-nextcloud-cert] Generating nextcloud-dev certificate"
    openssl genrsa -out "${CERT_KEY}" 2048 >/dev/null 2>&1
    openssl req -new -key "${CERT_KEY}" -out "${CERT_DIR}/nextcloud-dev.csr" -config "${CSR_CONFIG}" >/dev/null 2>&1
    openssl x509 -req -in "${CERT_DIR}/nextcloud-dev.csr" \
      -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
      -out "${CERT_FILE}" -days 825 -sha256 \
      -extensions req_ext -extfile "${CSR_CONFIG}" >/dev/null 2>&1
    cat "${CA_CERT}" >> "${CERT_FILE}"
    rm -f "${CERT_DIR}/nextcloud-dev.csr"
  else
    echo "[ensure-nextcloud-cert] Existing certificate already contains nextcloud-dev.lan SAN"
  fi
}

ensure_bundle() {
  if [[ ! -f "${BUNDLE}" ]]; then
    touch "${BUNDLE}"
  fi
  if ! grep -q "Nextcloud Dev Root" "${BUNDLE}" 2>/dev/null; then
    echo "[ensure-nextcloud-cert] Appending development root CA to custom bundle"
    cat "${CA_CERT}" >> "${BUNDLE}"
  fi
}

ensure_ca
ensure_cert
ensure_bundle

echo "[ensure-nextcloud-cert] Done."
