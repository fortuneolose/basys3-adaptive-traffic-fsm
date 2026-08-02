#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
mkdir -p build reports
rtl=(rtl/input_synchronizer.sv rtl/button_debouncer.sv rtl/tick_generator.sv
     rtl/seven_segment_driver.sv rtl/traffic_controller.sv rtl/traffic_controller_top.sv)
iverilog -g2012 -Wall -s tb_traffic_controller -o build/traffic_controller_tb \
  "${rtl[@]}" tb/tb_traffic_controller.sv 2>&1 | tee reports/iverilog_compile.log
vvp build/traffic_controller_tb 2>&1 | tee reports/simulation.log
