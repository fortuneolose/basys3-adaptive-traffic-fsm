SHELL := /bin/bash
.SHELLFLAGS := -o pipefail -c

RTL := rtl/input_synchronizer.sv rtl/button_debouncer.sv rtl/tick_generator.sv \
       rtl/seven_segment_driver.sv rtl/traffic_controller.sv rtl/traffic_controller_top.sv
TB := tb/tb_traffic_controller.sv
BUILD := build
REPORTS := reports

.PHONY: all sim compile lint vivado vivado-project vivado-project-build clean
all: sim

$(BUILD) $(REPORTS):
	mkdir -p $@

compile: $(BUILD) $(REPORTS)
	iverilog -g2012 -Wall -s tb_traffic_controller -o $(BUILD)/traffic_controller_tb $(RTL) $(TB) 2>&1 | tee $(REPORTS)/iverilog_compile.log

sim: compile
	vvp $(BUILD)/traffic_controller_tb 2>&1 | tee $(REPORTS)/simulation.log

lint: $(REPORTS)
	iverilog -g2012 -Wall -tnull -s traffic_controller_top $(RTL) 2>&1 | tee $(REPORTS)/iverilog_lint.log

vivado: $(REPORTS)
	vivado -mode batch -source scripts/run_vivado.tcl -notrace 2>&1 | tee $(REPORTS)/vivado_console.log

vivado-project:
	vivado -mode batch -source scripts/create_vivado_project.tcl -notrace

vivado-project-build: vivado-project
	vivado -mode batch -source scripts/build_vivado_project.tcl -notrace 2>&1 | tee $(REPORTS)/vivado_project_build.log

clean:
	rm -rf $(BUILD)
