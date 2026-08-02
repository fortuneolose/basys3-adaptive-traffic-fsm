set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set build_dir [file join $project_root build vivado]
set reports_dir [file join $project_root reports]
file mkdir $build_dir
file mkdir $reports_dir
set rtl_files [list \
    [file join $project_root rtl input_synchronizer.sv] \
    [file join $project_root rtl button_debouncer.sv] \
    [file join $project_root rtl tick_generator.sv] \
    [file join $project_root rtl seven_segment_driver.sv] \
    [file join $project_root rtl traffic_controller.sv] \
    [file join $project_root rtl traffic_controller_top.sv]]
read_verilog -sv $rtl_files
read_xdc [file join $project_root constraints basys3_traffic_controller.xdc]
synth_design -top traffic_controller_top -part xc7a35tcpg236-1
write_checkpoint -force [file join $build_dir post_synth.dcp]
report_utilization -file [file join $reports_dir utilization_post_synth.rpt]
report_clock_utilization -file [file join $reports_dir clock_utilization.rpt]
report_methodology -file [file join $reports_dir methodology_post_synth.rpt]
opt_design
place_design
phys_opt_design
route_design
write_checkpoint -force [file join $build_dir post_route.dcp]
report_utilization -file [file join $reports_dir utilization_post_route.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file [file join $reports_dir timing_summary.rpt]
report_drc -file [file join $reports_dir drc.rpt]
report_methodology -file [file join $reports_dir methodology_post_route.rpt]
set worst_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
if {[llength $worst_path] == 0} { error "No constrained max-delay timing path found" }
if {[get_property SLACK $worst_path] < 0} { error "Timing constraints were not met" }
puts "VIVADO_FLOW_PASS"
