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
    input wire csr_we_i,
    input wire[`MemAddrBus] csr_waddr_i,
    input wire[`RegBus] csr_rdata_i,
    input wire int_assert_i,
    input wire[`InstAddrBus] int_addr_i,
    input wire[`MemAddrBus] op1_i,
    input wire[`MemAddrBus] op2_i,
    input wire[`MemAddrBus] jump_addr_i,

    input wire[`MemBus] mem_rdata_i,

    input wire div_ready_i,
    input wire[`RegBus] div_result_i,
    input wire div_busy_i,
    input wire[`RegAddrBus] div_reg_waddr_i,

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

    output reg[`RegBus] csr_wdata_o,
    output wire csr_we_o,
    output wire[`MemAddrBus] csr_waddr_o,

    output wire div_start_o,
    output reg[`RegBus] div_dividend_o,
    output reg[`RegBus] div_divisor_o,
    output reg[2:0] div_op_o,
    output reg[`RegAddrBus] div_reg_waddr_o,

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
    wire[`DoubleRegBus] mul_temp;
    wire[`DoubleRegBus] mul_temp_invert;
    wire[31:0] sr_shift;
    wire[31:0] sr_shift_mask;
    wire[31:0] op1_add_op2_res;
    wire[31:0] reg1_data_invert;
    wire[31:0] reg2_data_invert;
    wire op1_ge_op2_signed;
    wire op1_ge_op2_unsigned;
    wire op1_eq_op2;
    wire is_div_op;
    wire is_custom_op;
    wire is_alu_op;
    wire is_load_op;
    wire is_store_op;
    wire is_branch_op;
    wire is_csr_op;
    reg[`RegBus] mul_op1;
    reg[`RegBus] mul_op2;
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
    reg[`RegBus] csr_unit_wdata;
    reg[`RegBus] csr_reg_wdata;
    reg[`RegBus] reg_wdata;
    reg reg_we;
    reg[`RegAddrBus] reg_waddr;
    reg[`RegBus] div_wdata;
    reg div_we;
    reg[`RegAddrBus] div_waddr;
    reg div_hold_flag;
    reg div_jump_flag;
    reg[`InstAddrBus] div_jump_addr;
    reg hold_flag;
    reg jump_flag;
    reg[`InstAddrBus] jump_addr;
    reg mem_we;
    reg mem_req;
    reg div_start;

    assign sr_shift = op1_i >> op2_i[4:0];
    assign sr_shift_mask = 32'hffffffff >> op2_i[4:0];
    assign op1_add_op2_res = op1_i + op2_i;
    assign reg1_data_invert = ~op1_i + 1;
    assign reg2_data_invert = ~reg2_rdata_i + 1;
    assign op1_ge_op2_signed = $signed(op1_i) >= $signed(op2_i);
    assign op1_ge_op2_unsigned = op1_i >= op2_i;
    assign op1_eq_op2 = (op1_i == op2_i);
    assign mul_temp = mul_op1 * mul_op2;
    assign mul_temp_invert = ~mul_temp + 1;
    assign mem_raddr_index = op1_add_op2_res[1:0];
    assign mem_waddr_index = op1_add_op2_res[1:0];
    assign is_div_op = (ex_ctrl == `EX_CTRL_DIV) || (ex_ctrl == `EX_CTRL_DIVU) ||
                       (ex_ctrl == `EX_CTRL_REM) || (ex_ctrl == `EX_CTRL_REMU);
    assign is_custom_op = (ex_ctrl == `EX_CTRL_CUSTOM_SID) ||
                          (ex_ctrl == `EX_CTRL_CUSTOM_RT) ||
                          (ex_ctrl == `EX_CTRL_CUSTOM_IF);
    assign is_alu_op = (ex_ctrl == `EX_CTRL_ADD) || (ex_ctrl == `EX_CTRL_SUB) ||
                       (ex_ctrl == `EX_CTRL_SLL) || (ex_ctrl == `EX_CTRL_SLT) ||
                       (ex_ctrl == `EX_CTRL_SLTU) || (ex_ctrl == `EX_CTRL_XOR) ||
                       (ex_ctrl == `EX_CTRL_SRL) || (ex_ctrl == `EX_CTRL_SRA) ||
                       (ex_ctrl == `EX_CTRL_OR) || (ex_ctrl == `EX_CTRL_AND) ||
                       (ex_ctrl == `EX_CTRL_MUL) || (ex_ctrl == `EX_CTRL_MULH) ||
                       (ex_ctrl == `EX_CTRL_MULHSU) || (ex_ctrl == `EX_CTRL_MULHU);
    assign is_load_op = (ex_ctrl == `EX_CTRL_LB) || (ex_ctrl == `EX_CTRL_LH) ||
                        (ex_ctrl == `EX_CTRL_LW) || (ex_ctrl == `EX_CTRL_LBU) ||
                        (ex_ctrl == `EX_CTRL_LHU);
    assign is_store_op = (ex_ctrl == `EX_CTRL_SB) || (ex_ctrl == `EX_CTRL_SH) ||
                         (ex_ctrl == `EX_CTRL_SW);
    assign is_branch_op = (ex_ctrl == `EX_CTRL_BEQ) || (ex_ctrl == `EX_CTRL_BNE) ||
                          (ex_ctrl == `EX_CTRL_BLT) || (ex_ctrl == `EX_CTRL_BGE) ||
                          (ex_ctrl == `EX_CTRL_BLTU) || (ex_ctrl == `EX_CTRL_BGEU) ||
                          (ex_ctrl == `EX_CTRL_JUMP) || (ex_ctrl == `EX_CTRL_FENCE);
    assign is_csr_op = (ex_ctrl == `EX_CTRL_CSRRW) || (ex_ctrl == `EX_CTRL_CSRRS) ||
                       (ex_ctrl == `EX_CTRL_CSRRC) || (ex_ctrl == `EX_CTRL_CSRRWI) ||
                       (ex_ctrl == `EX_CTRL_CSRRSI) || (ex_ctrl == `EX_CTRL_CSRRCI);

    assign custom_valid_o = is_custom_op;
    assign custom_op_o = ex_ctrl;
    assign custom_rd_o = reg_waddr_i;
    assign custom_op1_o = op1_i;
    assign custom_op2_o = op2_i;
    assign custom_reg2_rdata_o = reg2_rdata_i;

    assign div_start_o = (int_assert_i == `INT_ASSERT)? `DivStop: div_start;
    assign reg_wdata_o = reg_wdata | div_wdata;
    assign reg_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: (reg_we || div_we);
    assign reg_waddr_o = reg_waddr | div_waddr;
    assign mem_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: mem_we;
    assign mem_req_o = (int_assert_i == `INT_ASSERT)? `RIB_NREQ: mem_req;
    assign hold_flag_o = hold_flag || div_hold_flag;
    assign jump_flag_o = jump_flag || div_jump_flag || ((int_assert_i == `INT_ASSERT)? `JumpEnable: `JumpDisable);
    assign jump_addr_o = (int_assert_i == `INT_ASSERT)? int_addr_i: (jump_addr | div_jump_addr);
    assign csr_we_o = (int_assert_i == `INT_ASSERT)? `WriteDisable: csr_we_i;
    assign csr_waddr_o = csr_waddr_i;

    always @ (*) begin
        case (ex_ctrl)
            `EX_CTRL_MULH: begin
                mul_op1 = (op1_i[31] == 1'b1)? reg1_data_invert: op1_i;
                mul_op2 = (reg2_rdata_i[31] == 1'b1)? reg2_data_invert: reg2_rdata_i;
            end
            `EX_CTRL_MULHSU: begin
                mul_op1 = (op1_i[31] == 1'b1)? reg1_data_invert: op1_i;
                mul_op2 = reg2_rdata_i;
            end
            default: begin
                mul_op1 = op1_i;
                mul_op2 = reg2_rdata_i;
            end
        endcase
    end

    always @ (*) begin
        div_dividend_o = op1_i;
        div_divisor_o = op2_i;
        div_reg_waddr_o = reg_waddr_i;
        case (ex_ctrl)
            `EX_CTRL_DIV:  div_op_o = `INST_DIV;
            `EX_CTRL_DIVU: div_op_o = `INST_DIVU;
            `EX_CTRL_REM:  div_op_o = `INST_REM;
            `EX_CTRL_REMU: div_op_o = `INST_REMU;
            default:       div_op_o = `INST_DIV;
        endcase

        if (is_div_op) begin
            div_we = `WriteDisable;
            div_wdata = `ZeroWord;
            div_waddr = `ZeroWord;
            div_start = `DivStart;
            div_jump_flag = `JumpEnable;
            div_hold_flag = `HoldEnable;
            div_jump_addr = jump_addr_i;
        end else begin
            div_jump_flag = `JumpDisable;
            div_jump_addr = `ZeroWord;
            if (div_busy_i == `True) begin
                div_start = `DivStart;
                div_we = `WriteDisable;
                div_wdata = `ZeroWord;
                div_waddr = `ZeroWord;
                div_hold_flag = `HoldEnable;
            end else begin
                div_start = `DivStop;
                div_hold_flag = `HoldDisable;
                if (div_ready_i == `DivResultReady) begin
                    div_wdata = div_result_i;
                    div_waddr = div_reg_waddr_i;
                    div_we = `WriteEnable;
                end else begin
                    div_we = `WriteDisable;
                    div_wdata = `ZeroWord;
                    div_waddr = `ZeroWord;
                end
            end
        end
    end

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
            `EX_CTRL_MUL: begin
                alu_reg_wdata = mul_temp[31:0];
            end
            `EX_CTRL_MULHU: begin
                alu_reg_wdata = mul_temp[63:32];
            end
            `EX_CTRL_MULH: begin
                case ({op1_i[31], reg2_rdata_i[31]})
                    2'b00, 2'b11: alu_reg_wdata = mul_temp[63:32];
                    default:      alu_reg_wdata = mul_temp_invert[63:32];
                endcase
            end
            `EX_CTRL_MULHSU: begin
                alu_reg_wdata = (op1_i[31] == 1'b1) ? mul_temp_invert[63:32] : mul_temp[63:32];
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
        csr_unit_wdata = `ZeroWord;
        csr_reg_wdata = `ZeroWord;
        case (ex_ctrl)
            `EX_CTRL_CSRRW, `EX_CTRL_CSRRWI: begin
                csr_unit_wdata = op1_i;
                csr_reg_wdata = csr_rdata_i;
            end
            `EX_CTRL_CSRRS, `EX_CTRL_CSRRSI: begin
                csr_unit_wdata = op1_i | csr_rdata_i;
                csr_reg_wdata = csr_rdata_i;
            end
            `EX_CTRL_CSRRC, `EX_CTRL_CSRRCI: begin
                csr_unit_wdata = csr_rdata_i & (~op1_i);
                csr_reg_wdata = csr_rdata_i;
            end
            default: begin
                csr_unit_wdata = `ZeroWord;
                csr_reg_wdata = `ZeroWord;
            end
        endcase
    end

    always @ (*) begin
        reg_we = reg_we_i;
        reg_waddr = reg_waddr_i;
        mem_req = `RIB_NREQ;
        csr_wdata_o = `ZeroWord;
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
        end else if (is_csr_op) begin
            csr_wdata_o = csr_unit_wdata;
            reg_wdata = csr_reg_wdata;
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
            csr_wdata_o = `ZeroWord;
        end
    end

endmodule
