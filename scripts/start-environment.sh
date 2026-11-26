#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/environment-common.sh"

if [[ ! -f "$floci_dir/docker-compose.yml" ]]; then
  printf 'Floci Compose file not found. Set FLOCI_DIR to your Floci checkout.\n' >&2
  exit 1
fi

if ! read_api_pid; then
  if curl --silent --output /dev/null --max-time 2 "$api_url/health"; then
    printf 'Another service is already using %s. Set PDFPIPELINE_API_PORT to a free port.\n' "$api_url" >&2
    exit 1
  fi
  dotnet build "$repo_root/src/api/PdfPipeline.Api.csproj" --configuration Debug 9>&-
fi

compose up -d floci

wait_for_http() {
  local url=$1
  for ((attempt = 0; attempt < 30; attempt++)); do
    if curl --fail --silent --output /dev/null --max-time 2 "$url"; then
      return 0
    fi
    sleep 1
  done
  printf 'Timed out waiting for %s\n' "$url" >&2
  return 1
}

floci_url=${TF_VAR_floci_endpoint:-http://localhost:4566}
wait_for_http "${floci_url%/}/_floci/health"

if ! read_api_pid; then
  (
    cd "$repo_root/src/api"
    exec nohup dotnet "$api_dll" --urls "$api_url"
  ) </dev/null >"$run_dir/api.log" 2>&1 9>&- &
  printf '%s\n' "$!" > "$pid_file"
fi

if ! wait_for_http "$api_url/health" || ! read_api_pid; then
  printf 'API startup failed. See %s/api.log\n' "$run_dir" >&2
  exit 1
fi

printf 'API ready at %s/health\n' "$api_url"
