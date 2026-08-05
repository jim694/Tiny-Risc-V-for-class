set script_dir [file dirname [file normalize [info script]]]
set repo_root [file normalize [file join $script_dir .. ..]]
set smoke_dir [file normalize [file join $repo_root .. tiny_risc_v_vivado vio_smoke]]
set part xc7a35tfgg484-2

file mkdir $smoke_dir
create_project vio_smoke $smoke_dir -part $part -force

add_files [file join $repo_root rtl soc vio_smoke_top.v]
set_property top vio_smoke_top [get_filesets sources_1]

create_ip -name vio -vendor xilinx.com -library ip -version 3.0 -module_name vio_0
set_property -dict [list \
    CONFIG.C_NUM_PROBE_IN {2} \
    CONFIG.C_PROBE_IN0_WIDTH {4} \
    CONFIG.C_PROBE_IN1_WIDTH {32} \
    CONFIG.C_PROBE_OUT0_WIDTH {3} \
] [get_ips vio_0]
generate_target all [get_ips vio_0]
synth_ip [get_ips vio_0] -force

update_compile_order -fileset sources_1
synth_design -top vio_smoke_top -part $part
write_checkpoint -force [file join $smoke_dir vio_smoke_synth.dcp]
report_utilization -file [file join $smoke_dir vio_smoke_utilization.rpt]
report_drc -file [file join $smoke_dir vio_smoke_drc.rpt]
puts "VIO_SMOKE_PASS"
