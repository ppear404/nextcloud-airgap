#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${STACK_DIR}/logs/containers"
NEXTCLOUD_APP_SERVICE="app"
NEXTCLOUD_APP_LOG_PATH="/var/www/html/data/nextcloud.log"

mkdir -p "${LOG_DIR}"

if ! command -v docker >/dev/null 2>&1; then
  echo "docker command not found. Please install Docker or add it to PATH." >&2
  exit 1
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE_CMD=(docker compose)
elif command -v docker-compose >/dev/null 2>&1; then
  COMPOSE_CMD=(docker-compose)
else
  echo "docker compose command not available. Install Docker Compose v2 or v1." >&2
  exit 1
fi

services=()
while IFS= read -r svc; do
  [[ -n "${svc}" ]] && services+=("${svc}")
done < <("${COMPOSE_CMD[@]}" ps --services)

if ((${#services[@]} == 0)); then
  echo "No services are currently running. Start the stack before collecting logs." >&2
  exit 1
fi

pids=()

cleanup() {
  trap - INT TERM EXIT
  for pid in "${pids[@]}"; do
    kill "${pid}" 2>/dev/null || true
  done
}

trap cleanup INT TERM EXIT

for svc in "${services[@]}"; do
  log_file="${LOG_DIR}/${svc}.log"
  : >"${log_file}"
  echo "Capturing logs for ${svc} -> ${log_file}"
  (
    if command -v stdbuf >/dev/null 2>&1; then
      stdbuf -oL -eL "${COMPOSE_CMD[@]}" logs --no-color --timestamps -f "${svc}" 2>&1 |
        stdbuf -oL -eL sed "s/^/[${svc}] /" >>"${log_file}"
    else
      "${COMPOSE_CMD[@]}" logs --no-color --timestamps -f "${svc}" 2>&1 |
        sed "s/^/[${svc}] /" >>"${log_file}"
    fi
  ) &
  pids+=("$!")
done

nextcloud_service_running=false
for svc in "${services[@]}"; do
  if [[ "${svc}" == "${NEXTCLOUD_APP_SERVICE}" ]]; then
    nextcloud_service_running=true
    break
  fi
done

if [[ "${nextcloud_service_running}" == true ]]; then
  nextcloud_log_file="${LOG_DIR}/nextcloud.log"
  : >"${nextcloud_log_file}"
  echo "Capturing Nextcloud application log -> ${nextcloud_log_file}"
  (
    if command -v stdbuf >/dev/null 2>&1; then
      stdbuf -oL -eL "${COMPOSE_CMD[@]}" exec -T "${NEXTCLOUD_APP_SERVICE}" \
        sh -c 'touch "$1" && tail -n0 -F "$1"' _ "${NEXTCLOUD_APP_LOG_PATH}" 2>&1 |
        stdbuf -oL -eL sed "s/^/[nextcloud.log] /" >>"${nextcloud_log_file}"
    else
      "${COMPOSE_CMD[@]}" exec -T "${NEXTCLOUD_APP_SERVICE}" \
        sh -c 'touch "$1" && tail -n0 -F "$1"' _ "${NEXTCLOUD_APP_LOG_PATH}" 2>&1 |
        sed "s/^/[nextcloud.log] /" >>"${nextcloud_log_file}"
    fi
  ) &
  pids+=("$!")
else
  echo "Skipping Nextcloud application log capture; service '${NEXTCLOUD_APP_SERVICE}' not running." >&2
fi

wait
