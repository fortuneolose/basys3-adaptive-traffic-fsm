# Build the persistent Vivado project through bitstream generation and copy the
# most useful output artifacts to stable repository paths.

set script_dir   [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_name basys3_adaptive_traffic_controller
set project_dir  [file join $project_root vivado]
set project_file [file join $project_dir ${project_name}.xpr]
set reports_dir  [file join $project_root reports]
set artifacts_dir [file join $project_root artifacts]

if {![file isfile $project_file]} {
    source [file join $script_dir create_vivado_project.tcl]
}

file mkdir $reports_dir
file mkdir $artifacts_dir
open_project $project_file

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
if {![string match "*Complete*" $synth_status]} {
    error "Synthesis did not complete successfully: $synth_status"
}

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
if {![string match "*Complete*" $impl_status]} {
    error "Implementation/bitstream generation did not complete successfully: $impl_status"
}

open_run impl_1
report_utilization -file [file join $reports_dir vivado_project_utilization.rpt]
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose \
    -file [file join $reports_dir vivado_project_timing_summary.rpt]
report_drc -file [file join $reports_dir vivado_project_drc.rpt]

set worst_path [get_timing_paths -delay_type max -max_paths 1 -nworst 1]
if {[llength $worst_path] == 0} {
    error "No constrained maximum-delay timing path was found"
}
set worst_slack [get_property SLACK $worst_path]
if {$worst_slack < 0} {
    error "Timing constraints were not met; worst slack is $worst_slack ns"
}

set bitstream_file [file join $project_dir ${project_name}.runs impl_1 traffic_controller_top.bit]
if {![file isfile $bitstream_file]} {
    error "Expected bitstream was not generated: $bitstream_file"
}
file copy -force $bitstream_file [file join $artifacts_dir traffic_controller_top.bit]

puts "VIVADO_PROJECT_BUILD_PASS"
puts "SYNTHESIS_STATUS: $synth_status"
puts "IMPLEMENTATION_STATUS: $impl_status"
puts "WORST_SETUP_SLACK_NS: $worst_slack"
puts "BITSTREAM: [file join $artifacts_dir traffic_controller_top.bit]"

close_project
