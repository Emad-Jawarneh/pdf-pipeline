#!/usr/bin/env bash

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
floci_dir=${FLOCI_DIR:-"$HOME/floci"}
run_dir="$repo_root/.local-run"
api_dll="$repo_root/src/api/bin/Debug/net10.0/PdfPipeline.Api.dll"
api_url="http://127.0.0.1:${PDFPIPELINE_API_PORT:-5080}"
pid_file="$run_dir/api.pid"

mkdir -p "$run_dir"
exec 9>"$run_dir/environment.lock"
flock -w 120 9
trap 'flock -u 9' EXIT

compose() {
  docker compose --project-directory "$floci_dir" \
    -f "$floci_dir/docker-compose.yml" \
    -f "$repo_root/infra/environments/local/floci.compose.yml" "$@"
}

read_api_pid() {
  [[ -f "$pid_file" ]] && read -r api_pid < "$pid_file" &&
    [[ "$api_pid" =~ ^[1-9][0-9]*$ ]] &&
    grep -Fxzq -- "$api_dll" "/proc/$api_pid/cmdline" 2>/dev/null
}
