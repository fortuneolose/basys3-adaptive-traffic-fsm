#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_file="$project_root/vivado/basys3_adaptive_traffic_controller.xpr"

if ! command -v vivado >/dev/null 2>&1; then
    echo "ERROR: Vivado is not on PATH." >&2
    exit 1
fi

if [[ ! -f "$project_file" ]]; then
    vivado -mode batch -source "$project_root/scripts/create_vivado_project.tcl" -notrace
fi

exec vivado "$project_file"
