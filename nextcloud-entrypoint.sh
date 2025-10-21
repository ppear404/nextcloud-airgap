#!/bin/bash
set -euo pipefail

ORIGINAL_ENTRYPOINT="/entrypoint.sh"
BOOTSTRAP_SCRIPT="/appapi-bootstrap.sh"
CUSTOM_CA_SOURCES=(/certs/*rootCA*.crt /certs/*rootCA*.pem)
CUSTOM_BUNDLE="/certs/custom-ca-bundle.pem"
SYSTEM_BUNDLE="/etc/ssl/certs/ca-certificates.crt"
GENERATED_BUNDLE="/etc/ssl/certs/custom-ca-bundle.generated.pem"

build_custom_bundle() {
  local tmp_bundle="/tmp/custom-ca-bundle.pem"
  : >"${tmp_bundle}"

  if [[ -f "${SYSTEM_BUNDLE}" && -s "${SYSTEM_BUNDLE}" ]]; then
    cat "${SYSTEM_BUNDLE}" >>"${tmp_bundle}"
  fi

  if [[ -f "${CUSTOM_BUNDLE}" && -s "${CUSTOM_BUNDLE}" ]]; then
    cat "${CUSTOM_BUNDLE}" >>"${tmp_bundle}"
  fi

  for source in "${CUSTOM_CA_SOURCES[@]}"; do
    [[ -f "${source}" ]] || continue
    cat "${source}" >>"${tmp_bundle}"
  done

  if [[ -s "${tmp_bundle}" ]]; then
    if cp "${tmp_bundle}" "${GENERATED_BUNDLE}"; then
      chmod 0644 "${GENERATED_BUNDLE}" || true
      export SSL_CERT_FILE="${GENERATED_BUNDLE}"
      export CURL_CA_BUNDLE="${GENERATED_BUNDLE}"
      export REQUESTS_CA_BUNDLE="${GENERATED_BUNDLE}"
    else
      echo "Warning: Failed to write combined CA bundle to ${GENERATED_BUNDLE}." >&2
      export SSL_CERT_FILE="${SYSTEM_BUNDLE}"
      export CURL_CA_BUNDLE="${SYSTEM_BUNDLE}"
      export REQUESTS_CA_BUNDLE="${SYSTEM_BUNDLE}"
    fi
  else
    rm -f "${tmp_bundle}"
    export SSL_CERT_FILE="${SYSTEM_BUNDLE}"
    export CURL_CA_BUNDLE="${SYSTEM_BUNDLE}"
    export REQUESTS_CA_BUNDLE="${SYSTEM_BUNDLE}"
    return
  fi

  rm -f "${tmp_bundle}"
}

ensure_custom_ca() {
  local updated=false
  for source in "${CUSTOM_CA_SOURCES[@]}"; do
    [[ -f "${source}" ]] || continue
    local filename
    filename=$(basename "${source}")
    local target="/usr/local/share/ca-certificates/${filename%.pem}.crt"
    if [[ "${source}" == *.crt ]]; then
      target="/usr/local/share/ca-certificates/${filename}"
    fi
    if [[ ! -f "${target}" ]] || ! cmp -s "${source}" "${target}"; then
      cp "${source}" "${target}"
      updated=true
    fi
  done
  if [[ "${updated}" == true ]]; then
    update-ca-certificates >/dev/null 2>&1 || true
  fi

  if [[ -f "${CUSTOM_BUNDLE}" ]]; then
    # Ensure the combined bundle contains the custom mkcert root if update-ca-certificates isn't available
    if [[ ! -s "${SYSTEM_BUNDLE}" ]]; then
      cp "${CUSTOM_BUNDLE}" "${SYSTEM_BUNDLE}"
    fi
  fi

  build_custom_bundle
}

cleanup() {
  if [[ -n "${ENTRYPOINT_PID:-}" ]]; then
    kill "${ENTRYPOINT_PID}" 2>/dev/null || true
  fi
}

trap cleanup INT TERM

ensure_custom_ca

"${ORIGINAL_ENTRYPOINT}" "$@" &
ENTRYPOINT_PID=$!

if [[ -x "${BOOTSTRAP_SCRIPT}" ]]; then
  if ! "${BOOTSTRAP_SCRIPT}"; then
    echo "AppAPI bootstrap script failed." >&2
    cleanup
    wait "${ENTRYPOINT_PID}" || true
    exit 1
  fi
else
  echo "Bootstrap script ${BOOTSTRAP_SCRIPT} not found or not executable; skipping." >&2
fi

wait "${ENTRYPOINT_PID}"
