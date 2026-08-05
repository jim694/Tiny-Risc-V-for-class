set repo_root [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set project_file [file normalize [file join $repo_root .. tiny_risc_v_vivado tiny_risc_v_vivado.xpr]]
open_project $project_file
update_compile_order -fileset sources_1
reset_run synth_1
reset_run impl_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} { error "main synthesis failed" }
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} { error "main implementation failed" }
puts "MAIN_VIVADO_PASS"
close_project
