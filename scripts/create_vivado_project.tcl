# Create a portable Vivado project around the repository-owned RTL, constraints,
# and testbenches. Run this script from any working directory.

set script_dir   [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ..]]
set project_name basys3_adaptive_traffic_controller
set project_dir  [file join $project_root vivado]
set project_file [file join $project_dir ${project_name}.xpr]
set target_part  xc7a35tcpg236-1

set rtl_files [list \
    [file join $project_root rtl input_synchronizer.sv] \
    [file join $project_root rtl button_debouncer.sv] \
    [file join $project_root rtl tick_generator.sv] \
    [file join $project_root rtl seven_segment_driver.sv] \
    [file join $project_root rtl traffic_controller.sv] \
    [file join $project_root rtl traffic_controller_top.sv]]

set constraint_file [file join $project_root constraints basys3_traffic_controller.xdc]
set simulation_files [list \
    [file join $project_root tb tb_traffic_controller.sv] \
    [file join $project_root tb tb_traffic_controller_showcase.sv]]

foreach required_file [concat $rtl_files [list $constraint_file] $simulation_files] {
    if {![file isfile $required_file]} {
        error "Required project source is missing: $required_file"
    }
}

if {[llength [get_projects -quiet]] > 0} {
    close_project -quiet
}

file mkdir $project_dir
create_project -force $project_name $project_dir -part $target_part

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
set_property default_lib xil_defaultlib [current_project]

add_files -fileset sources_1 -norecurse $rtl_files
set_property top traffic_controller_top [get_filesets sources_1]

add_files -fileset constrs_1 -norecurse $constraint_file

add_files -fileset sim_1 -norecurse $simulation_files
set_property top tb_traffic_controller [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Produce a .bit file from the normal implementation run and retain a .bin file
# for users who later add a supported nonvolatile programming flow.
set_property STEPS.WRITE_BITSTREAM.ARGS.BIN_FILE true [get_runs impl_1]

close_project

if {![file isfile $project_file]} {
    error "Vivado did not create the expected project file: $project_file"
}

puts "VIVADO_PROJECT_CREATED: $project_file"
