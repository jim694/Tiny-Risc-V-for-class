set repo_root [file normalize [file join [file dirname [file normalize [info script]]] .. ..]]
set project_file [file normalize [file join $repo_root .. tiny_risc_v_vivado tiny_risc_v_vivado.xpr]]
open_project $project_file

set remove_sources {}
foreach source_file [get_files -of_objects [get_filesets sources_1]] {
    set normalized [string tolower [file normalize $source_file]]
    if {[regexp {/(clint|csr_reg|div)\.v$} $normalized] ||
        [regexp {/rtl/debug/jtag_(dm|driver|top)\.v$} $normalized] ||
        [regexp {/(tinyriscv_single|core_select|full_handshake_rx|full_handshake_tx|gen_buf)\.v$} $normalized] ||
        [regexp {/fpga/tinyriscv_fpga_top\.v$} $normalized]} {
        lappend remove_sources $source_file
    }
}
if {[llength $remove_sources] > 0} {
    remove_files -fileset [get_filesets sources_1] $remove_sources
}

set remove_sim {}
foreach sim_file [get_files -of_objects [get_filesets sim_1]] {
    set normalized [string tolower [file normalize $sim_file]]
    if {[regexp {/(clint|csr_reg|div)\.v$} $normalized] ||
        [regexp {/rtl/debug/jtag_(dm|driver|top)\.v$} $normalized] ||
        [regexp {/(tinyriscv_single|core_select|full_handshake_rx|full_handshake_tx|gen_buf)\.v$} $normalized] ||
        [regexp {/fpga/tinyriscv_fpga_top\.v$} $normalized]} {
        lappend remove_sim $sim_file
    }
}
if {[llength $remove_sim] > 0} {
    remove_files -fileset [get_filesets sim_1] $remove_sim
}

set rtl_files [list \
    [file join $repo_root rtl/cluster/tinyriscv_cluster.v] \
    [file join $repo_root rtl/soc/tinyriscv_fpga_top.v] \
]
add_files -fileset sources_1 $rtl_files
add_files -fileset sim_1 $rtl_files

set_property top tinyriscv_fpga_top [get_filesets sources_1]
set_property top tinyriscv_soc_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
save_project_as -force $project_file
close_project
puts "VIVADO_REDUCED_FILELIST_PASS"
