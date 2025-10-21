#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="${STACK_DIR}/logs/containers"

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

wait
