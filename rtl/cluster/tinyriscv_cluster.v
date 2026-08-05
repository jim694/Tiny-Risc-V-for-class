`timescale 1ns/1ps
`include "../core/defines.v"

// Current project slot: one local processor and one shared register file.
// The chip_sel boundary is retained for future group integration; unpopulated
// slots are deliberately inert.
module tinyriscv_cluster(
    input wire clk,
    input wire rst,
    input wire [2:0] chip_sel_i,

    input wire[`MemBus] rib_ex_data_i,
    input wire[`MemBus] rib_pc_data_i,
    input wire rib_hold_flag_i,

    output wire[`MemAddrBus] rib_ex_addr_o,
    output wire[`MemBus] rib_ex_data_o,
    output wire rib_ex_req_o,
    output wire rib_ex_we_o,
    output wire[`MemAddrBus] rib_pc_addr_o,
    output wire [3:0] selected_o,
    output wire[`RegBus] test_x26_o,
    output wire[`RegBus] test_x27_o
    );

    wire core_selected = (chip_sel_i == 3'b000);
    wire core_rst = rst & core_selected;

    wire[`MemAddrBus] core_ex_addr;
    wire[`MemBus] core_ex_data_i;
    wire[`MemBus] core_ex_data_o;
    wire core_ex_req;
    wire core_ex_we;
    wire[`MemAddrBus] core_pc_addr;
    wire[`RegAddrBus] core_rf_raddr1;
    wire[`RegBus] core_rf_rdata1;
    wire[`RegAddrBus] core_rf_raddr2;
    wire[`RegBus] core_rf_rdata2;
    wire core_rf_we;
    wire[`RegAddrBus] core_rf_waddr;
    wire[`RegBus] core_rf_wdata;
    wire[`RegBus] shared_rf_rdata1;
    wire[`RegBus] shared_rf_rdata2;

    assign selected_o = core_selected ? 4'b0001 : 4'b0000;
    assign rib_ex_addr_o = core_selected ? core_ex_addr : `ZeroWord;
    assign rib_ex_data_o = core_selected ? core_ex_data_o : `ZeroWord;
    assign rib_ex_req_o = core_selected ? core_ex_req : 1'b0;
    assign rib_ex_we_o = core_selected ? core_ex_we : 1'b0;
    assign rib_pc_addr_o = core_selected ? core_pc_addr : `ZeroWord;
    assign core_ex_data_i = rib_ex_data_i;
    assign core_rf_rdata1 = shared_rf_rdata1;
    assign core_rf_rdata2 = shared_rf_rdata2;

    tinyriscv u_core(
        .clk(clk),
        .rst(core_rst),
        .rib_ex_addr_o(core_ex_addr),
        .rib_ex_data_i(core_ex_data_i),
        .rib_ex_data_o(core_ex_data_o),
        .rib_ex_req_o(core_ex_req),
        .rib_ex_we_o(core_ex_we),
        .rib_pc_addr_o(core_pc_addr),
        .rib_pc_data_i(rib_pc_data_i),
        .rf_raddr1_o(core_rf_raddr1),
        .rf_rdata1_i(core_rf_rdata1),
        .rf_raddr2_o(core_rf_raddr2),
        .rf_rdata2_i(core_rf_rdata2),
        .rf_we_o(core_rf_we),
        .rf_waddr_o(core_rf_waddr),
        .rf_wdata_o(core_rf_wdata),
        .rib_hold_flag_i(rib_hold_flag_i)
    );

    regs u_regs(
        .clk(clk),
        .rst(rst),
        .we_i(core_selected && core_rf_we),
        .waddr_i(core_rf_waddr),
        .wdata_i(core_rf_wdata),
        .raddr1_i(core_rf_raddr1),
        .rdata1_o(shared_rf_rdata1),
        .raddr2_i(core_rf_raddr2),
        .rdata2_o(shared_rf_rdata2)
    );

    assign test_x26_o = u_regs.regs[26];
    assign test_x27_o = u_regs.regs[27];

endmodule
