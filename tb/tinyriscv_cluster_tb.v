`timescale 1ns/1ps
`include "../rtl/core/defines.v"

module tinyriscv_cluster_tb;
    reg clk;
    reg rst;
    reg [2:0] chip_sel;
    reg [`MemBus] rib_ex_data_i;
    reg [`MemBus] rib_pc_data_i;
    reg rib_hold_flag_i;
    wire [`MemAddrBus] rib_ex_addr_o;
    wire [`MemBus] rib_ex_data_o;
    wire rib_ex_req_o;
    wire rib_ex_we_o;
    wire [`MemAddrBus] rib_pc_addr_o;
    wire [3:0] selected_o;

    tinyriscv_cluster dut(
        .clk(clk),
        .rst(rst),
        .chip_sel_i(chip_sel),
        .rib_ex_data_i(rib_ex_data_i),
        .rib_pc_data_i(rib_pc_data_i),
        .rib_hold_flag_i(rib_hold_flag_i),
        .rib_ex_addr_o(rib_ex_addr_o),
        .rib_ex_data_o(rib_ex_data_o),
        .rib_ex_req_o(rib_ex_req_o),
        .rib_ex_we_o(rib_ex_we_o),
        .rib_pc_addr_o(rib_pc_addr_o),
        .selected_o(selected_o)
    );

    always #5 clk = ~clk;

    task check_selected;
        input [2:0] sel;
        input [3:0] expected;
        begin
            chip_sel = sel;
            #1;
            if (selected_o !== expected) begin
                $display("FAIL chip_sel=%b selected=%b", sel, selected_o);
                $finish(1);
            end
            if (dut.core_rst !== expected[0]) begin
                $display("FAIL chip_sel=%b core_rst=%b", sel, dut.core_rst);
                $finish(1);
            end
        end
    endtask

    initial begin
        clk = 1'b0;
        rst = `RstDisable;
        chip_sel = 3'b000;
        rib_ex_data_i = `ZeroWord;
        rib_pc_data_i = `INST_NOP;
        rib_hold_flag_i = `HoldDisable;
        check_selected(3'b000, 4'b0001);
        check_selected(3'b001, 4'b0000);
        check_selected(3'b010, 4'b0000);
        check_selected(3'b011, 4'b0000);
        check_selected(3'b111, 4'b0000);
        $display("PASS tinyriscv_cluster");
        $finish(0);
    end
endmodule
