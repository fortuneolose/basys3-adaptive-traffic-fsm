#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
mkdir -p waveforms reports

sim_binary="waveforms/.traffic_showcase.vvp"
trap 'rm -f "$sim_binary"' EXIT

iverilog -g2012 -Wall -s tb_traffic_controller_showcase \
  -o "$sim_binary" \
  rtl/traffic_controller.sv \
  tb/tb_traffic_controller_showcase.sv \
  2>&1 | tee reports/waveform_compile.log

vvp "$sim_binary" 2>&1 | tee reports/waveform_simulation.log
vcd2fst waveforms/traffic_showcase.vcd waveforms/traffic_showcase.fst

printf '%s\n' \
  'Generated:' \
  '  waveforms/traffic_showcase.vcd' \
  '  waveforms/traffic_showcase.fst' \
  '  waveforms/traffic_showcase.gtkw' \
  '' \
  'Open with:' \
  '  gtkwave waveforms/traffic_showcase.fst waveforms/traffic_showcase.gtkw'
