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
CUSTOM=false
# Additional cert targets
TALK_KEY="${CERT_DIR}/talk-dev.lan-key.pem"
TALK_CERT="${CERT_DIR}/talk-dev.lan.pem"
COLLAB_KEY="${CERT_DIR}/collabora-dev.lan-key.pem"
COLLAB_CERT="${CERT_DIR}/collabora-dev.lan.pem"

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
    --custom)
      CUSTOM=true
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

# Request EKUs: server and client auth
extendedKeyUsage = serverAuth, clientAuth

[ alt_names ]
DNS.1 = nextcloud-dev.lan
DNS.2 = nextcloud-dev
CFG
fi

# Helper to write a temporary CSR config for a name+optional SANs
write_csr_config() {
  local out="$1"; shift
  local cn="$1"; shift
  local idx=1
  cat >"${out}" <<CFG
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
CN = ${cn}

[ req_ext ]
subjectAltName = @alt_names
# Request EKUs: server and client auth
extendedKeyUsage = serverAuth, clientAuth

[ alt_names ]
CFG
  while [[ $# -gt 0 ]]; do
    echo "DNS.${idx} = $1" >>"${out}"
    idx=$((idx+1))
    shift
  done
}

# Create a certificate for a CN with optional SANs
create_cert() {
  local cn="$1"; shift
  local keypath="$1"; shift
  local certpath="$1"; shift
  local sans=("$@")

  local cn_safe
  cn_safe=$(echo "${cn}" | tr '.' '-')
  local tmpcfg="${CERT_DIR}/${cn_safe}.cnf"
  local csrfile="${CERT_DIR}/${cn_safe}.csr"

  write_csr_config "${tmpcfg}" "${cn}" "${sans[@]}"
  openssl genrsa -out "${keypath}" 2048 >/dev/null 2>&1
  openssl req -new -key "${keypath}" -out "${csrfile}" -config "${tmpcfg}" >/dev/null 2>&1
  openssl x509 -req -in "${csrfile}" \
    -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
    -out "${certpath}" -days 825 -sha256 \
    -extensions req_ext -extfile "${tmpcfg}" >/dev/null 2>&1
  cat "${CA_CERT}" >> "${certpath}"
  rm -f "${csrfile}" "${tmpcfg}"
}

# Prompt user for one or more custom certs (interactive)
prompt_custom() {
  echo "[ensure-nextcloud-cert] Enter custom certificates to create. Leave CN empty to finish."
  while true; do
    read -rp "  Common Name (hostname) (blank to finish): " cn
    if [[ -z "${cn// /}" ]]; then
      break
    fi
    read -rp "  SANs (comma-separated, e.g. example.lan,www.example.lan) (leave blank to use CN): " sans_input
    IFS=',' read -r -a sans_arr <<< "${sans_input}"
    # Trim whitespace and default to CN if empty
    local san_list=()
    if [[ -z "${sans_input}" ]]; then
      san_list=("${cn}")
    else
      for s in "${sans_arr[@]}"; do
        s_trim=$(echo "$s" | sed -e 's/^\s*//' -e 's/\s*$//')
        if [[ -n "${s_trim}" ]]; then
          san_list+=("${s_trim}")
        fi
      done
      # Ensure CN is included
      local found_cn=false
      for s in "${san_list[@]}"; do
        if [[ "$s" == "$cn" ]]; then
          found_cn=true
          break
        fi
      done
      if [[ "$found_cn" == false ]]; then
        san_list+=("${cn}")
      fi
    fi

    keyfile="${CERT_DIR}/${cn}-key.pem"
    certfile="${CERT_DIR}/${cn}.pem"
    echo "[ensure-nextcloud-cert] Creating custom cert for ${cn} with SANs: ${san_list[*]}"
    create_cert "${cn}" "${keyfile}" "${certfile}" "${san_list[@]}"
  done
}

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
  # Generate nextcloud-dev (uses static CSR_CONFIG)
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

  # Generate talk-dev.lan
  if [[ "${FORCE}" == true || ! -f "${TALK_CERT}" ]]; then
    echo "[ensure-nextcloud-cert] Generating talk-dev.lan certificate"
    tmpcfg="${CERT_DIR}/talk-dev.cnf"
    write_csr_config "${tmpcfg}" "talk-dev.lan" "talk-dev.lan"
    openssl genrsa -out "${TALK_KEY}" 2048 >/dev/null 2>&1
    openssl req -new -key "${TALK_KEY}" -out "${CERT_DIR}/talk-dev.csr" -config "${tmpcfg}" >/dev/null 2>&1
    openssl x509 -req -in "${CERT_DIR}/talk-dev.csr" \
      -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
      -out "${TALK_CERT}" -days 825 -sha256 \
      -extensions req_ext -extfile "${tmpcfg}" >/dev/null 2>&1
    cat "${CA_CERT}" >> "${TALK_CERT}"
    rm -f "${CERT_DIR}/talk-dev.csr" "${tmpcfg}"
  else
    echo "[ensure-nextcloud-cert] talk-dev.lan certificate already exists"
  fi

  # Generate collabora-dev.lan
  if [[ "${FORCE}" == true || ! -f "${COLLAB_CERT}" ]]; then
    echo "[ensure-nextcloud-cert] Generating collabora-dev.lan certificate"
    tmpcfg="${CERT_DIR}/collabora-dev.cnf"
    write_csr_config "${tmpcfg}" "collabora-dev.lan" "collabora-dev.lan"
    openssl genrsa -out "${COLLAB_KEY}" 2048 >/dev/null 2>&1
    openssl req -new -key "${COLLAB_KEY}" -out "${CERT_DIR}/collabora-dev.csr" -config "${tmpcfg}" >/dev/null 2>&1
    openssl x509 -req -in "${CERT_DIR}/collabora-dev.csr" \
      -CA "${CA_CERT}" -CAkey "${CA_KEY}" -CAcreateserial \
      -out "${COLLAB_CERT}" -days 825 -sha256 \
      -extensions req_ext -extfile "${tmpcfg}" >/dev/null 2>&1
    cat "${CA_CERT}" >> "${COLLAB_CERT}"
    rm -f "${CERT_DIR}/collabora-dev.csr" "${tmpcfg}"
  else
    echo "[ensure-nextcloud-cert] collabora-dev.lan certificate already exists"
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
if [[ "${CUSTOM}" == true ]]; then
  prompt_custom
fi
ensure_bundle

echo "[ensure-nextcloud-cert] Done."
