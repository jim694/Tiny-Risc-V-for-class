/*
 Copyright 2020 Blue Liang, liangkangnan@163.com
 Licensed under the Apache License, Version 2.0.
*/

`include "defines.v"

module id_ex(

    input wire clk,
    input wire rst,

    input wire[`ExCtrlBus] ex_ctrl_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] reg2_rdata_i,
    input wire csr_we_i,
    input wire[`MemAddrBus] csr_waddr_i,
    input wire[`RegBus] csr_rdata_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] jump_addr_i,

    input wire[`Hold_Flag_Bus] hold_flag_i,

    output wire[`MemAddrBus] op1_o,
    output wire[`MemAddrBus] op2_o,
    output wire[`MemAddrBus] jump_addr_o,
    output wire[`ExCtrlBus] ex_ctrl_o,
    output wire reg_we_o,
    output wire[`RegAddrBus] reg_waddr_o,
    output wire[`RegBus] reg2_rdata_o,
    output wire csr_we_o,
    output wire[`MemAddrBus] csr_waddr_o,
    output wire[`RegBus] csr_rdata_o

    );

    wire flush_en  = (hold_flag_i == `Hold_Id);
    wire freeze_en = (hold_flag_i == `Hold_Freeze);

    wire[`ExCtrlBus] ex_ctrl;
    gen_pipe_dff #(`ExCtrlWidth) ex_ctrl_ff(clk, rst, flush_en, freeze_en, `EX_CTRL_NOP, ex_ctrl_i, ex_ctrl);
    assign ex_ctrl_o = ex_ctrl;

    wire reg_we;
    gen_pipe_dff #(1) reg_we_ff(clk, rst, flush_en, freeze_en, `WriteDisable, reg_we_i, reg_we);
    assign reg_we_o = reg_we;

    wire[`RegAddrBus] reg_waddr;
    gen_pipe_dff #(5) reg_waddr_ff(clk, rst, flush_en, freeze_en, `ZeroReg, reg_waddr_i, reg_waddr);
    assign reg_waddr_o = reg_waddr;

    wire[`RegBus] reg2_rdata;
    gen_pipe_dff #(32) reg2_rdata_ff(clk, rst, flush_en, freeze_en, `ZeroWord, reg2_rdata_i, reg2_rdata);
    assign reg2_rdata_o = reg2_rdata;

    wire csr_we;
    gen_pipe_dff #(1) csr_we_ff(clk, rst, flush_en, freeze_en, `WriteDisable, csr_we_i, csr_we);
    assign csr_we_o = csr_we;

    wire[`MemAddrBus] csr_waddr;
    gen_pipe_dff #(32) csr_waddr_ff(clk, rst, flush_en, freeze_en, `ZeroWord, csr_waddr_i, csr_waddr);
    assign csr_waddr_o = csr_waddr;

    wire[`RegBus] csr_rdata;
    gen_pipe_dff #(32) csr_rdata_ff(clk, rst, flush_en, freeze_en, `ZeroWord, csr_rdata_i, csr_rdata);
    assign csr_rdata_o = csr_rdata;

    wire[`MemAddrBus] op1;
    gen_pipe_dff #(32) op1_ff(clk, rst, flush_en, freeze_en, `ZeroWord, op1_i, op1);
    assign op1_o = op1;

    wire[`MemAddrBus] op2;
    gen_pipe_dff #(32) op2_ff(clk, rst, flush_en, freeze_en, `ZeroWord, op2_i, op2);
    assign op2_o = op2;

    wire[`MemAddrBus] jump_addr;
    gen_pipe_dff #(32) jump_addr_ff(clk, rst, flush_en, freeze_en, `ZeroWord, jump_addr_i, jump_addr);
    assign jump_addr_o = jump_addr;

endmodule
