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

    input wire uart_debug_pin,

    output wire uart_tx_pin,
    input wire uart_rx_pin,

    output wire [3:0] pwm_o,

    output wire       io_scl,
    inout  wire       io_sda

    );

    wire [7:0] ext_mem_out_w;
    wire [7:0] ext_mem_in_w;
    wire [2:0] chip_sel = 3'b000;
    wire [3:0] selected;

    tinyriscv_soc_top u_soc(
        .clk(clk),
        .rst(rst),
        .over(over),
        .succ(succ),
        .uart_debug_pin(uart_debug_pin),
        .uart_tx_pin(uart_tx_pin),
        .uart_rx_pin(uart_rx_pin),
        .pwm_o(pwm_o),
        .io_scl(io_scl),
        .io_sda(io_sda),
        .ext_mem_out(ext_mem_out_w),
        .ext_mem_in(ext_mem_in_w),
        .chip_sel(chip_sel),
        .selected_o(selected)
    );

    fpga_mem_bridge u_fpga_mem_bridge(
        .clk(clk),
        .rst(rst),
        .ext_in_i(ext_mem_out_w),
        .ext_out_o(ext_mem_in_w)
    );

endmodule
