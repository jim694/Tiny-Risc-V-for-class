/*
 Copyright 2026

 FPGA verification wrapper for TinyRISCV SoC.
 The final SoC boundary ends at ext_mem_out/ext_mem_in; this wrapper keeps
 fpga_mem_bridge and its ROM/RAM model outside the SoC for FPGA validation.
*/

module tinyriscv_fpga_top(

    input wire clk,
    input wire rst,

    output wire over,
    output wire succ,

    output wire halted_ind,

    input wire uart_debug_pin,

    output wire uart_tx_pin,
    input wire uart_rx_pin,

    input wire jtag_TCK,
    input wire jtag_TMS,
    input wire jtag_TDI,
    output wire jtag_TDO,

    output wire [3:0] pwm_o,

    output wire       io_scl,
    inout  wire       io_sda

    );

    wire [7:0] ext_mem_out_w;
    wire [7:0] ext_mem_in_w;

    tinyriscv_soc_top u_soc(
        .clk(clk),
        .rst(rst),
        .over(over),
        .succ(succ),
        .halted_ind(halted_ind),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .jtag_TCK(jtag_TCK),
        .jtag_TMS(jtag_TMS),
        .jtag_TDI(jtag_TDI),
        .jtag_TDO(jtag_TDO),
        .pwm_o(pwm_o),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .ext_mem_out(ext_mem_out_w),
        .ext_mem_in(ext_mem_in_w)
    );

    fpga_mem_bridge u_fpga_mem_bridge(
        .clk(clk),
        .rst(rst),
        .ext_in_i(ext_mem_out_w),
        .ext_out_o(ext_mem_in_w)
    );

endmodule
