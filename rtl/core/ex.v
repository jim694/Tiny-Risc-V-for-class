/*
 Copyright 2019 Blue Liang, liangkangnan@163.com
 Licensed under the Apache License, Version 2.0.
*/

`include "defines.v"

module ex(

    input wire clk,
    input wire rst,

    input wire[`ExCtrlBus] ex_ctrl_i,
    input wire reg_we_i,
    input wire[`RegAddrBus] reg_waddr_i,
    input wire[`RegBus] reg2_rdata_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] jump_addr_i,

    input wire[`MemBus] mem_rdata_i,

    input wire custom_busy_i,
    input wire custom_done_i,
    input wire custom_reg_we_i,
    input wire[`RegAddrBus] custom_reg_waddr_i,
    input wire[`RegBus] custom_reg_wdata_i,
    input wire custom_mem_req_i,
    input wire custom_mem_we_i,
    input wire[`MemAddrBus] custom_mem_addr_i,
    input wire[`MemBus] custom_mem_wdata_i,

    output reg[`MemBus] mem_wdata_o,
    output reg[`MemAddrBus] mem_raddr_o,
    output reg[`MemAddrBus] mem_waddr_o,
    output wire mem_we_o,
    output wire mem_req_o,

    output wire[`RegBus] reg_wdata_o,
    output wire reg_we_o,
    output wire[`RegAddrBus] reg_waddr_o,

    output wire custom_valid_o,
    output wire[`ExCtrlBus] custom_op_o,
    output wire[`RegAddrBus] custom_rd_o,
    output wire[`RegBus] custom_op1_o,
    output wire[`RegBus] custom_op2_o,
    output wire[`RegBus] custom_reg2_rdata_o,

    output wire hold_flag_o,
    output wire jump_flag_o,
    output wire[`InstAddrBus] jump_addr_o

    );

    wire[`ExCtrlBus] ex_ctrl = ex_ctrl_i;
    wire[1:0] mem_raddr_index;
    wire[1:0] mem_waddr_index;
    wire[31:0] sr_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire is_custom_op;
    wire is_alu_op;
    wire is_load_op;
    wire is_store_op;
    wire is_branch_op;
    reg[`RegBus] alu_reg_wdata;
    reg[`RegBus] lsu_reg_wdata;
    reg lsu_mem_req;
    reg lsu_mem_we;
    reg[`MemAddrBus] lsu_mem_raddr;
    reg[`MemAddrBus] lsu_mem_waddr;
    reg[`MemBus] lsu_mem_wdata;
    reg branch_jump_flag;
    reg[`InstAddrBus] branch_jump_addr;
    reg[`RegBus] branch_reg_wdata;
    reg[`RegBus] reg_wdata;
    reg reg_we;
    reg[`RegAddrBus] reg_waddr;
    reg hold_flag;
    reg jump_flag;
    reg[`InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;

    assign sr_shift = op1_i >> op2_i[4:0];
    assign sr_shift_mask = 32'hffffffff >> op2_i[4:0];
    assign op1_add_op2_res = op1_i + op2_i;
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);
    assign mem_raddr_index = op1_add_op2_res[1:0];
    assign mem_waddr_index = op1_add_op2_res[1:0];
    assign is_custom_op = (ex_ctrl == `EX_CTRL_CUSTOM_SID) ||
                          (ex_ctrl == `EX_CTRL_CUSTOM_RT) ||
                          (ex_ctrl == `EX_CTRL_CUSTOM_IF);
    assign is_alu_op = (ex_ctrl == `EX_CTRL_ADD) || (ex_ctrl == `EX_CTRL_SUB) ||
                       (ex_ctrl == `EX_CTRL_SLL) || (ex_ctrl == `EX_CTRL_SLT) ||
                       (ex_ctrl == `EX_CTRL_SLTU) || (ex_ctrl == `EX_CTRL_XOR) ||
                       (ex_ctrl == `EX_CTRL_SRL) || (ex_ctrl == `EX_CTRL_SRA) ||
                       (ex_ctrl == `EX_CTRL_OR) || (ex_ctrl == `EX_CTRL_AND);
    assign is_load_op = (ex_ctrl == `EX_CTRL_LB) || (ex_ctrl == `EX_CTRL_LH) ||
                        (ex_ctrl == `EX_CTRL_LW) || (ex_ctrl == `EX_CTRL_LBU) ||
                        (ex_ctrl == `EX_CTRL_LHU);
    assign is_store_op = (ex_ctrl == `EX_CTRL_SB) || (ex_ctrl == `EX_CTRL_SH) ||
                         (ex_ctrl == `EX_CTRL_SW);
    assign is_branch_op = (ex_ctrl == `EX_CTRL_BEQ) || (ex_ctrl == `EX_CTRL_BNE) ||
                          (ex_ctrl == `EX_CTRL_BLT) || (ex_ctrl == `EX_CTRL_BGE) ||
                          (ex_ctrl == `EX_CTRL_BLTU) || (ex_ctrl == `EX_CTRL_BGEU) ||
                          (ex_ctrl == `EX_CTRL_JUMP) || (ex_ctrl == `EX_CTRL_FENCE);

    assign custom_valid_o = is_custom_op;
    assign custom_op_o = ex_ctrl;
    assign custom_rd_o = reg_waddr_i;
    assign custom_op1_o = op1_i;
    assign custom_op2_o = op2_i;
    assign custom_reg2_rdata_o = reg2_rdata_i;

    assign reg_wdata_o = reg_wdata;
    assign reg_we_o = reg_we;
    assign reg_waddr_o = reg_waddr;
    assign mem_we_o = mem_we;
    assign mem_req_o = mem_req;
    assign hold_flag_o = hold_flag;
    assign jump_flag_o = jump_flag;
    assign jump_addr_o = jump_addr;

    always @ (*) begin
        alu_reg_wdata = `ZeroWord;
        case (ex_ctrl)
            `EX_CTRL_ADD: begin
                alu_reg_wdata = op1_add_op2_res;
            end
            `EX_CTRL_SUB: begin
                alu_reg_wdata = op1_i - op2_i;
            end
            `EX_CTRL_SLL: begin
                alu_reg_wdata = op1_i << op2_i[4:0];
            end
            `EX_CTRL_SLT: begin
                alu_reg_wdata = {32{(~op1_ge_op2_signed)}} & 32'h1;
            end
            `EX_CTRL_SLTU: begin
                alu_reg_wdata = {32{(~op1_ge_op2_unsigned)}} & 32'h1;
            end
            `EX_CTRL_XOR: begin
                alu_reg_wdata = op1_i ^ op2_i;
            end
            `EX_CTRL_SRL: begin
                alu_reg_wdata = op1_i >> op2_i[4:0];
            end
            `EX_CTRL_SRA: begin
                alu_reg_wdata = (sr_shift & sr_shift_mask) | ({32{op1_i[31]}} & (~sr_shift_mask));
            end
            `EX_CTRL_OR: begin
                alu_reg_wdata = op1_i | op2_i;
            end
            `EX_CTRL_AND: begin
                alu_reg_wdata = op1_i & op2_i;
            end
            default: begin
                alu_reg_wdata = `ZeroWord;
            end
        endcase
    end

    always @ (*) begin
        lsu_reg_wdata = `ZeroWord;
        lsu_mem_req = `RIB_NREQ;
        lsu_mem_we = `WriteDisable;
        lsu_mem_raddr = `ZeroWord;
        lsu_mem_waddr = `ZeroWord;
        lsu_mem_wdata = `ZeroWord;

        case (ex_ctrl)
            `EX_CTRL_LB: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_raddr = op1_add_op2_res;
                case (mem_raddr_index)
                    2'b00: lsu_reg_wdata = {{24{mem_rdata_i[7]}}, mem_rdata_i[7:0]};
                    2'b01: lsu_reg_wdata = {{24{mem_rdata_i[15]}}, mem_rdata_i[15:8]};
                    2'b10: lsu_reg_wdata = {{24{mem_rdata_i[23]}}, mem_rdata_i[23:16]};
                    default: lsu_reg_wdata = {{24{mem_rdata_i[31]}}, mem_rdata_i[31:24]};
                endcase
            end
            `EX_CTRL_LH: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_raddr = op1_add_op2_res;
                if (mem_raddr_index == 2'b00)
                    lsu_reg_wdata = {{16{mem_rdata_i[15]}}, mem_rdata_i[15:0]};
                else
                    lsu_reg_wdata = {{16{mem_rdata_i[31]}}, mem_rdata_i[31:16]};
            end
            `EX_CTRL_LW: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_raddr = op1_add_op2_res;
                lsu_reg_wdata = mem_rdata_i;
            end
            `EX_CTRL_LBU: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_raddr = op1_add_op2_res;
                case (mem_raddr_index)
                    2'b00: lsu_reg_wdata = {24'h0, mem_rdata_i[7:0]};
                    2'b01: lsu_reg_wdata = {24'h0, mem_rdata_i[15:8]};
                    2'b10: lsu_reg_wdata = {24'h0, mem_rdata_i[23:16]};
                    default: lsu_reg_wdata = {24'h0, mem_rdata_i[31:24]};
                endcase
            end
            `EX_CTRL_LHU: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_raddr = op1_add_op2_res;
                if (mem_raddr_index == 2'b00)
                    lsu_reg_wdata = {16'h0, mem_rdata_i[15:0]};
                else
                    lsu_reg_wdata = {16'h0, mem_rdata_i[31:16]};
            end
            `EX_CTRL_SB: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_we = `WriteEnable;
                lsu_mem_raddr = op1_add_op2_res;
                lsu_mem_waddr = op1_add_op2_res;
                case (mem_waddr_index)
                    2'b00: lsu_mem_wdata = {mem_rdata_i[31:8], reg2_rdata_i[7:0]};
                    2'b01: lsu_mem_wdata = {mem_rdata_i[31:16], reg2_rdata_i[7:0], mem_rdata_i[7:0]};
                    2'b10: lsu_mem_wdata = {mem_rdata_i[31:24], reg2_rdata_i[7:0], mem_rdata_i[15:0]};
                    default: lsu_mem_wdata = {reg2_rdata_i[7:0], mem_rdata_i[23:0]};
                endcase
            end
            `EX_CTRL_SH: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_we = `WriteEnable;
                lsu_mem_raddr = op1_add_op2_res;
                lsu_mem_waddr = op1_add_op2_res;
                if (mem_waddr_index == 2'b00)
                    lsu_mem_wdata = {mem_rdata_i[31:16], reg2_rdata_i[15:0]};
                else
                    lsu_mem_wdata = {reg2_rdata_i[15:0], mem_rdata_i[15:0]};
            end
            `EX_CTRL_SW: begin
                lsu_mem_req = `RIB_REQ;
                lsu_mem_we = `WriteEnable;
                lsu_mem_raddr = op1_add_op2_res;
                lsu_mem_waddr = op1_add_op2_res;
                lsu_mem_wdata = reg2_rdata_i;
            end
            default: begin
                lsu_reg_wdata = `ZeroWord;
            end
        endcase
    end

    always @ (*) begin
        branch_jump_flag = `JumpDisable;
        branch_jump_addr = `ZeroWord;
        branch_reg_wdata = `ZeroWord;
        case (ex_ctrl)
            `EX_CTRL_BEQ: begin
                branch_jump_flag = op1_eq_op2 & `JumpEnable;
                branch_jump_addr = {32{op1_eq_op2}} & jump_addr_i;
            end
            `EX_CTRL_BNE: begin
                branch_jump_flag = (~op1_eq_op2) & `JumpEnable;
                branch_jump_addr = {32{(~op1_eq_op2)}} & jump_addr_i;
            end
            `EX_CTRL_BLT: begin
                branch_jump_flag = (~op1_ge_op2_signed) & `JumpEnable;
                branch_jump_addr = {32{(~op1_ge_op2_signed)}} & jump_addr_i;
            end
            `EX_CTRL_BGE: begin
                branch_jump_flag = op1_ge_op2_signed & `JumpEnable;
                branch_jump_addr = {32{op1_ge_op2_signed}} & jump_addr_i;
            end
            `EX_CTRL_BLTU: begin
                branch_jump_flag = (~op1_ge_op2_unsigned) & `JumpEnable;
                branch_jump_addr = {32{(~op1_ge_op2_unsigned)}} & jump_addr_i;
            end
            `EX_CTRL_BGEU: begin
                branch_jump_flag = op1_ge_op2_unsigned & `JumpEnable;
                branch_jump_addr = {32{op1_ge_op2_unsigned}} & jump_addr_i;
            end
            `EX_CTRL_JUMP: begin
                branch_jump_flag = `JumpEnable;
                branch_jump_addr = jump_addr_i;
                branch_reg_wdata = op1_add_op2_res;
            end
            `EX_CTRL_FENCE: begin
                branch_jump_flag = `JumpEnable;
                branch_jump_addr = jump_addr_i;
            end
            default: begin
                branch_jump_flag = `JumpDisable;
            end
        endcase
    end

    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `RIB_NREQ;
        jump_flag = `JumpDisable;
        hold_flag = `HoldDisable;
        jump_addr = `ZeroWord;
        mem_wdata_o = `ZeroWord;
        mem_raddr_o = `ZeroWord;
        mem_waddr_o = `ZeroWord;
        mem_we = `WriteDisable;
        reg_wdata = `ZeroWord;

        if (is_load_op || is_store_op) begin
            mem_req = lsu_mem_req;
            mem_we = lsu_mem_we;
            mem_raddr_o = lsu_mem_raddr;
            mem_waddr_o = lsu_mem_waddr;
            mem_wdata_o = lsu_mem_wdata;
            reg_wdata = lsu_reg_wdata;
        end else if (is_branch_op) begin
            jump_flag = branch_jump_flag;
            jump_addr = branch_jump_addr;
            reg_wdata = branch_reg_wdata;
        end else if (is_alu_op) begin
            reg_wdata = alu_reg_wdata;
        end else if (is_custom_op) begin
            hold_flag = custom_busy_i;
            reg_we = `WriteDisable;
        end

        if (custom_busy_i || custom_done_i) begin
            hold_flag   = custom_busy_i;
            reg_we      = custom_reg_we_i;
            reg_waddr   = custom_reg_waddr_i;
            reg_wdata   = custom_reg_wdata_i;
            mem_req     = custom_mem_req_i;
            mem_we      = custom_mem_we_i;
            mem_raddr_o = custom_mem_addr_i;
            mem_waddr_o = custom_mem_addr_i;
            mem_wdata_o = custom_mem_wdata_i;
            jump_flag   = `JumpDisable;
            jump_addr   = `ZeroWord;
        end
    end

endmodule
