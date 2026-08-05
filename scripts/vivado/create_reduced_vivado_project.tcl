set repo_root [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set project_root [file normalize [file join $repo_root .. reduced_vivado_project]]
set part xc7a35tfgg484-2

create_project reduced_vivado_project $project_root -part $part -force
set rtl_files [list \
    [file join $repo_root rtl/core/ctrl.v] \
    [file join $repo_root rtl/core/custom_unit.v] \
    [file join $repo_root rtl/core/defines.v] \
    [file join $repo_root rtl/core/ex.v] \
    [file join $repo_root rtl/core/id.v] \
    [file join $repo_root rtl/core/id_ex.v] \
    [file join $repo_root rtl/core/if_id.v] \
    [file join $repo_root rtl/core/pc_reg.v] \
    [file join $repo_root rtl/core/regs.v] \
    [file join $repo_root rtl/core/rib.v] \
    [file join $repo_root rtl/core/tinyriscv.v] \
    [file join $repo_root rtl/cluster/tinyriscv_cluster.v] \
    [file join $repo_root rtl/perips/uart.v] \
    [file join $repo_root rtl/perips/pwm.v] \
    [file join $repo_root rtl/perips/i2c.v] \
    [file join $repo_root rtl/bridge/rib_mem_bridge.v] \
    [file join $repo_root rtl/bridge/fpga_mem_bridge.v] \
    [file join $repo_root rtl/debug/uart_debug.v] \
    [file join $repo_root rtl/soc/tinyriscv_soc_top.v] \
    [file join $repo_root rtl/soc/tinyriscv_fpga_top.v] \
    [file join $repo_root rtl/utils/gen_dff.v] \
]
add_files -fileset sources_1 $rtl_files
add_files -fileset constrs_1 [file join $repo_root fpga/tinyriscv_soc_top.xdc]
add_files -fileset sim_1 [file join $repo_root tb/tinyriscv_soc_tb.v]
set_property top tinyriscv_fpga_top [get_filesets sources_1]
set_property top tinyriscv_soc_tb [get_filesets sim_1]
set_property include_dirs [list [file join $repo_root rtl/core]] [get_filesets sources_1]
set_property include_dirs [list [file join $repo_root rtl/core]] [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
    error "reduced synthesis failed"
}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
    error "reduced implementation failed"
}
puts "REDUCED_VIVADO_PASS"
