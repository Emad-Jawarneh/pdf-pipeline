#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/environment-common.sh"

if [[ ! -f "$floci_dir/docker-compose.yml" ]]; then
  printf 'Floci Compose file not found. Set FLOCI_DIR to your Floci checkout.\n' >&2
  exit 1
fi

if read_api_pid; then
  kill -TERM "$api_pid"
  for ((attempt = 0; attempt < 30; attempt++)); do
    read_api_pid || break
    sleep 1
  done
  if read_api_pid; then
    printf 'API process %s did not exit.\n' "$api_pid" >&2
    exit 1
  fi
fi
rm -f -- "$pid_file"

compose stop floci
