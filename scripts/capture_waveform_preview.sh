#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

if [[ ! -f waveforms/traffic_showcase.fst ]]; then
  ./scripts/generate_waveforms.sh
fi

xvfb-run -a --server-args="-screen 0 1600x1000x24" bash -c '
  gtkwave waveforms/traffic_showcase.fst waveforms/traffic_showcase.gtkw \
    >reports/gtkwave_preview.log 2>&1 &
  viewer_pid=$!
  sleep 3
  import -window root waveforms/traffic_showcase.png
  kill "$viewer_pid" 2>/dev/null || true
  wait "$viewer_pid" 2>/dev/null || true
'

echo "Generated waveforms/traffic_showcase.png"
