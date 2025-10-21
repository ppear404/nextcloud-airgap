#!/bin/bash
set -euo pipefail

log() {
  printf '[%s] %s\n' "$(date --iso-8601=seconds)" "$*"
}

NEXTCLOUD_ROOT="/var/www/html"
cd "${NEXTCLOUD_ROOT}"

if ! command -v runuser >/dev/null 2>&1; then
  log "runuser utility not found; cannot switch to www-data. Aborting."
  exit 1
fi

occ() {
  runuser -u www-data -- php occ "$@"
}

wait_for_nextcloud() {
  local status_output
  while true; do
    if status_output="$(occ status 2>&1)"; then
      if grep -q "installed: true" <<<"${status_output}"; then
        log "Nextcloud installation detected."
        break
      fi
      log "Nextcloud not fully installed yet. Waiting…"
    else
      log "Nextcloud not ready. Waiting…"
    fi
    sleep 10
  done
}

app_is_enabled() {
  local app_name="$1"
  local output
  if output="$(occ app:list --enabled 2>/dev/null)"; then
    grep -q " - ${app_name}" <<<"${output}"
    return
  fi

  output="$(occ app:list)"
  awk -v app="${app_name}" '
    /^Enabled:/ {enabled=1; next}
    enabled && /^Disabled:/ {enabled=0}
    enabled && $0 ~ " - " app {found=1}
    END {exit(found ? 0 : 1)}
  ' <<<"${output}"
}

app_is_installed() {
  local app_name="$1"
  occ app:list | grep -q " - ${app_name}:"
}

install_app() {
  local app_name="$1"
  local required="${2:-true}"

  if app_is_installed "${app_name}"; then
    log "App '${app_name}' already present."
    return 0
  fi

  log "Installing app '${app_name}'…"
  if ! occ app:install "${app_name}"; then
    log "Installation of '${app_name}' failed."
    if [[ "${required}" == "true" ]]; then
      return 1
    fi
    return 2
  fi

  return 0
}

enable_app() {
  local app_name="$1"
  local required="${2:-true}"

  if app_is_enabled "${app_name}"; then
    log "App '${app_name}' already enabled."
    return 0
  fi

  log "Enabling app '${app_name}'…"
  if ! occ app:enable "${app_name}"; then
    log "Enabling '${app_name}' failed."
    if [[ "${required}" == "true" ]]; then
      return 1
    fi
    return 2
  fi

  return 0
}

# Normalize various truthy/falsy inputs to literal "true" or "false"
normalize_bool() {
  local value="${1:-}"
  value="${value,,}"
  case "${value}" in
    1|true|yes|on) echo "true" ;;
    *) echo "false" ;;
  esac
}

bool_to_yesno() {
  if [[ "$(normalize_bool "${1:-}")" == "true" ]]; then
    echo "yes"
  else
    echo "no"
  fi
}

wait_for_nextcloud

if ! install_app "app_api" "true"; then
  log "Required app 'app_api' could not be installed; aborting."
  exit 1
fi
if ! enable_app "app_api" "true"; then
  log "Required app 'app_api' could not be enabled; aborting."
  exit 1
fi

log "Allowing local outbound requests to this host."
occ config:system:set allow_local_remote_servers --type=bool --value=true >/dev/null

if ! install_app "app_management" "false"; then
  log "Optional app 'app_management' is unavailable; continuing without it."
else
  if ! enable_app "app_management" "false"; then
    log "Optional app 'app_management' could not be enabled; continuing without it."
  fi
fi

# Build deploy daemon configuration from environment
DAEMON_NAME="${APPAPI_DAEMON_NAME:-harp_proxy_docker}"
DAEMON_DISPLAY_NAME="${APPAPI_DAEMON_DISPLAY_NAME:-HaRP Proxy (Docker)}"
DAEMON_METHOD="${APPAPI_DEPLOY_METHOD:-docker-install}"
DAEMON_PROTOCOL="${APPAPI_DAEMON_PROTOCOL:-http}"
DAEMON_HOST="${APPAPI_DAEMON_HOST:-nextcloud-harp:8780}"
DAEMON_NETWORK="${APPAPI_DAEMON_NETWORK:-proxy}"
DAEMON_COMPUTE="${APPAPI_COMPUTE_DEVICE:-cpu}"
DAEMON_SET_DEFAULT="${APPAPI_SET_DEFAULT:-true}"
DAEMON_ENABLE_HARP="${APPAPI_ENABLE_HARP:-true}"
NEXTCLOUD_URL="${APPAPI_NEXTCLOUD_URL:-${NC_INSTANCE_URL:-http://nextcloud-app}}"
HARP_FRP_ADDRESS="${APPAPI_HARP_FRP_ADDRESS:-nextcloud-harp:8782}"
HARP_SHARED_KEY="${APPAPI_HARP_SHARED_KEY:-${HP_SHARED_KEY:-}}"
HARP_SOCKET_PORT="${APPAPI_HARP_DOCKER_SOCKET_PORT:-}"
HARP_EXAPP_DIRECT="${APPAPI_HARP_EXAPP_DIRECT:-false}"

if [[ -z "${NEXTCLOUD_URL}" ]]; then
  log "APPAPI_NEXTCLOUD_URL/NC_INSTANCE_URL must be provided."
  exit 1
fi

if [[ "${DAEMON_ENABLE_HARP}" == "true" && -z "${HARP_SHARED_KEY}" ]]; then
  log "AppAPI HaRP shared key is required but missing."
  exit 1
fi

log "Registering AppAPI deploy daemon '${DAEMON_NAME}'…"
register_cmd=(
  app_api:daemon:register
  "${DAEMON_NAME}"
  "${DAEMON_DISPLAY_NAME}"
  "${DAEMON_METHOD}"
  "${DAEMON_PROTOCOL}"
  "${DAEMON_HOST}"
  "${NEXTCLOUD_URL}"
)

if [[ -n "${DAEMON_NETWORK}" ]]; then
  register_cmd+=("--net=${DAEMON_NETWORK}")
fi

register_cmd+=("--compute_device=${DAEMON_COMPUTE}")

if [[ "${DAEMON_SET_DEFAULT}" == "true" ]]; then
  register_cmd+=("--set-default")
fi

if [[ "${DAEMON_ENABLE_HARP}" == "true" ]]; then
  register_cmd+=("--harp" "--harp_frp_address=${HARP_FRP_ADDRESS}" "--harp_shared_key=${HARP_SHARED_KEY}")
  if [[ -n "${HARP_SOCKET_PORT}" ]]; then
    register_cmd+=("--harp_docker_socket_port=${HARP_SOCKET_PORT}")
  fi
  if [[ "${HARP_EXAPP_DIRECT}" == "true" ]]; then
    register_cmd+=("--harp_exapp_direct")
  fi
fi

if occ "${register_cmd[@]}"; then
  log "Deploy daemon registration completed."
else
  log "Deploy daemon registration failed."
  exit 1
fi

configure_collabora() {
  if [[ "$(normalize_bool "${COLLABORA_ENABLE:-true}")" != "true" ]]; then
    log "Collabora bootstrap disabled via COLLABORA_ENABLE; skipping."
    return 0
  fi

  local collabora_url="${COLLABORA_URL:-https://collabora-dev.lan}"
  if [[ -z "${collabora_url}" ]]; then
    log "Collabora configuration skipped: COLLABORA_URL is not set."
    return 0
  fi

  log "Ensuring Collabora Online app is present."
  if ! install_app "richdocuments" "true"; then
    log "Required app 'richdocuments' could not be installed; aborting."
    return 1
  fi
  if ! enable_app "richdocuments" "true"; then
    log "Required app 'richdocuments' could not be enabled; aborting."
    return 1
  fi

  collabora_url="${collabora_url%/}"
  log "Setting Collabora WOPI endpoint to ${collabora_url}."
  occ config:app:set richdocuments wopi_url --value "${collabora_url}" >/dev/null

  local public_url="${COLLABORA_PUBLIC_URL:-${collabora_url}}"
  if [[ -n "${public_url}" ]]; then
    public_url="${public_url%/}"
    log "Setting Collabora public WOPI endpoint to ${public_url}."
    occ config:app:set richdocuments public_wopi_url --value "${public_url}" >/dev/null
  fi

  local callback_url="${COLLABORA_CALLBACK_URL:-${NEXTCLOUD_URL:-${NC_INSTANCE_URL:-}}}"
  if [[ -n "${callback_url}" ]]; then
    callback_url="${callback_url%/}"
    log "Setting Collabora callback URL to ${callback_url}."
    occ config:app:set richdocuments wopi_callback_url --value "${callback_url}" >/dev/null
  fi

  local verify_tls="$(normalize_bool "${COLLABORA_VERIFY_TLS:-true}")"
  if [[ "${verify_tls}" == "true" ]]; then
    log "Enforcing Collabora TLS verification."
    occ config:app:delete richdocuments disable_certificate_verification >/dev/null 2>&1 || true
    occ config:app:delete richdocuments wopi_disable_certificate_check >/dev/null 2>&1 || true
  else
    log "Disabling Collabora TLS verification."
    occ config:app:set richdocuments disable_certificate_verification --value "yes" >/dev/null
    occ config:app:set richdocuments wopi_disable_certificate_check --value "yes" >/dev/null
  fi

  log "Collabora integration configured."
  return 0
}

configure_talk_hpb() {
  if [[ "$(normalize_bool "${TALK_HPB_ENABLE:-true}")" != "true" ]]; then
    log "Talk HPB bootstrap disabled via TALK_HPB_ENABLE; skipping."
    return 0
  fi

  local talk_host="${TALK_HOST:-}"
  local signaling_secret="${SIGNALING_SECRET:-}"

  if [[ -z "${talk_host}" ]]; then
    log "Talk HPB configuration skipped: TALK_HOST is not set."
    return 0
  fi
  if [[ -z "${signaling_secret}" ]]; then
    log "Talk HPB configuration skipped: SIGNALING_SECRET is not set."
    return 0
  fi

  log "Ensuring Nextcloud Talk app is present."
  if ! install_app "spreed" "true"; then
    log "Required app 'spreed' could not be installed; aborting."
    return 1
  fi
  if ! enable_app "spreed" "true"; then
    log "Required app 'spreed' could not be enabled; aborting."
    return 1
  fi

  local signaling_url="${TALK_SIGNALING_URL:-https://${talk_host}}"
  if [[ "${signaling_url}" != *"://"* ]]; then
    signaling_url="https://${signaling_url}"
  fi
  local verify_flag
  verify_flag="$(normalize_bool "${TALK_VERIFY_TLS:-true}")"

  local talk_port="${TALK_PORT:-3478}"
  local stun_server="${TALK_STUN_SERVER:-${talk_host}:${talk_port}}"
  local hide_warning
  hide_warning="$(normalize_bool "${TALK_HIDE_WARNING:-false}")"

  log "Configuring Talk signaling server at ${signaling_url} (verify TLS: ${verify_flag})."
  local signaling_json
  signaling_json=$(printf '{"servers":[{"server":"%s","verify":%s}],"secret":"%s"}' "${signaling_url}" "${verify_flag}" "${signaling_secret}")
  occ config:app:set spreed signaling_servers --value "${signaling_json}" >/dev/null

  if [[ -n "${stun_server}" ]]; then
    log "Setting Talk STUN server to ${stun_server}."
    local stun_json
    stun_json=$(printf '["%s"]' "${stun_server}")
    occ config:app:set spreed stun_servers --value "${stun_json}" >/dev/null
  else
    log "No STUN server configured; skipping STUN step."
  fi

  local turn_secret="${TURN_SECRET:-}"
  if [[ -n "${turn_secret}" ]]; then
    local turn_server="${TALK_TURN_SERVER:-${talk_host}:${talk_port}}"
    local turn_schemes="${TALK_TURN_SCHEMES:-turn}"
    local turn_protocols="${TALK_TURN_PROTOCOLS:-udp,tcp}"
    log "Setting Talk TURN server to ${turn_server} (schemes=${turn_schemes}, protocols=${turn_protocols})."
    local turn_json
    turn_json=$(printf '[{"schemes":"%s","server":"%s","secret":"%s","protocols":"%s"}]' "${turn_schemes}" "${turn_server}" "${turn_secret}" "${turn_protocols}")
    occ config:app:set spreed turn_servers --value "${turn_json}" >/dev/null
  else
    log "TURN_SECRET not provided; skipping TURN configuration."
  fi

  log "Updating Talk warning preference (hide warning: ${hide_warning})."
  occ config:app:set spreed hide_signaling_warning --value "$(bool_to_yesno "${hide_warning}")" >/dev/null

  log "Talk high-performance backend configuration completed."
  return 0
}

if ! configure_collabora; then
  log "Collabora bootstrap failed."
  exit 1
fi

if ! configure_talk_hpb; then
  log "Talk HPB bootstrap failed."
  exit 1
fi

log "Bootstrap tasks finished."
