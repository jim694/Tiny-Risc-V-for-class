`timescale 1ns/1ps
`include "defines.v"

// Single-core compatibility shell used by the current simulation and FPGA
// flows. The processor core itself owns no register-file storage.
module tinyriscv_single(
    input wire clk,
    input wire rst,

    output wire[`MemAddrBus] rib_ex_addr_o,
    input wire[`MemBus] rib_ex_data_i,
    output wire[`MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,

    output wire[`MemAddrBus] rib_pc_addr_o,
    input wire[`MemBus] rib_pc_data_i,
    input wire rib_hold_flag_i,

    output wire[`RegBus] test_x3_o,
    output wire[`RegBus] test_x26_o,
    output wire[`RegBus] test_x27_o
    );

    wire[`RegAddrBus] rf_raddr1;
    wire[`RegBus] rf_rdata1;
    wire[`RegAddrBus] rf_raddr2;
    wire[`RegBus] rf_rdata2;
    wire rf_we;
    wire[`RegAddrBus] rf_waddr;
    wire[`RegBus] rf_wdata;

    tinyriscv u_core(
        .clk(clk),
        .rst(rst),
        .rib_ex_addr_o(rib_ex_addr_o),
        .rib_ex_data_i(rib_ex_data_i),
        .rib_ex_data_o(rib_ex_data_o),
        .rib_ex_req_o(rib_ex_req_o),
        .rib_ex_we_o(rib_ex_we_o),
        .rib_pc_addr_o(rib_pc_addr_o),
        .rib_pc_data_i(rib_pc_data_i),
        .rf_raddr1_o(rf_raddr1),
        .rf_rdata1_i(rf_rdata1),
        .rf_raddr2_o(rf_raddr2),
        .rf_rdata2_i(rf_rdata2),
        .rf_we_o(rf_we),
        .rf_waddr_o(rf_waddr),
        .rf_wdata_o(rf_wdata),
        .rib_hold_flag_i(rib_hold_flag_i)
    );

    regs u_regs(
        .clk(clk),
        .rst(rst),
        .we_i(rf_we),
        .waddr_i(rf_waddr),
        .wdata_i(rf_wdata),
        .raddr1_i(rf_raddr1),
        .rdata1_o(rf_rdata1),
        .raddr2_i(rf_raddr2),
        .rdata2_o(rf_rdata2)
    );

    assign test_x3_o = u_regs.regs[3];
    assign test_x26_o = u_regs.regs[26];
    assign test_x27_o = u_regs.regs[27];

endmodule
