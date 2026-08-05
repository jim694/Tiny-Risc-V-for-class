set repo_root [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set project_file [file normalize [file join $repo_root .. tiny_risc_v_vivado tiny_risc_v_vivado.xpr]]
open_project $project_file
set_property top tinyriscv_soc_tb [get_filesets sim_1]
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
update_compile_order -fileset sim_1
launch_simulation
close_sim
close_project
puts "MAIN_XSIM_PASS"
