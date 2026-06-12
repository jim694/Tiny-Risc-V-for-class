/*
 Copyright 2019 Blue Liang, liangkangnan@163.com
 Licensed under the Apache License, Version 2.0.
*/

`include "defines.v"

module id(

    input wire rst,

    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,

    input wire[`RegBus] reg1_rdata_i,
    input wire[`RegBus] reg2_rdata_i,

    input wire[`RegBus] csr_rdata_i,

    input wire ex_jump_flag_i,

    output reg[`RegAddrBus] reg1_raddr_o,
    output reg[`RegAddrBus] reg2_raddr_o,

    output reg[`MemAddrBus] csr_raddr_o,

    output reg[`MemAddrBus] op1_o,
    output reg[`MemAddrBus] op2_o,
    output reg[`MemAddrBus] jump_addr_o,
    output reg[`ExCtrlBus] ex_ctrl_o,
    output reg[`InstAddrBus] inst_addr_o,
    output reg[`RegBus] reg2_rdata_o,
    output reg reg_we_o,
    output reg[`RegAddrBus] reg_waddr_o,
    output reg csr_we_o,
    output reg[`RegBus] csr_rdata_o,
    output reg[`MemAddrBus] csr_waddr_o

    );

    wire[6:0] opcode = inst_i[6:0];
    wire[2:0] funct3 = inst_i[14:12];
    wire[6:0] funct7 = inst_i[31:25];
    wire[4:0] rd = inst_i[11:7];
    wire[4:0] rs1 = inst_i[19:15];
    wire[4:0] rs2 = inst_i[24:20];
    wire bit30 = inst_i[30];

    always @ (*) begin
        inst_addr_o = inst_addr_i;
        ex_ctrl_o = `EX_CTRL_NOP;
        reg_we_o = `WriteDisable;
        reg_waddr_o = `ZeroReg;
        reg1_raddr_o = `ZeroReg;
        reg2_raddr_o = `ZeroReg;
        reg2_rdata_o = reg2_rdata_i;
        csr_rdata_o = csr_rdata_i;
        csr_raddr_o = `ZeroWord;
        csr_waddr_o = `ZeroWord;
        csr_we_o = `WriteDisable;
        op1_o = `ZeroWord;
        op2_o = `ZeroWord;
        jump_addr_o = `ZeroWord;

        case (opcode)
            `INST_TYPE_I: begin
                case (funct3)
                    `INST_ADDI:  ex_ctrl_o = `EX_CTRL_ADD;
                    `INST_SLTI:  ex_ctrl_o = `EX_CTRL_SLT;
                    `INST_SLTIU: ex_ctrl_o = `EX_CTRL_SLTU;
                    `INST_XORI:  ex_ctrl_o = `EX_CTRL_XOR;
                    `INST_ORI:   ex_ctrl_o = `EX_CTRL_OR;
                    `INST_ANDI:  ex_ctrl_o = `EX_CTRL_AND;
                    `INST_SLLI:  ex_ctrl_o = `EX_CTRL_SLL;
                    `INST_SRI:   ex_ctrl_o = bit30 ? `EX_CTRL_SRA : `EX_CTRL_SRL;
                    default:     ex_ctrl_o = `EX_CTRL_NOP;
                endcase
                if (ex_ctrl_o != `EX_CTRL_NOP) begin
                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    reg1_raddr_o = rs1;
                    reg2_raddr_o = `ZeroReg;
                    op1_o = reg1_rdata_i;
                    op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                end
            end

            `INST_TYPE_R_M: begin
                if ((funct7 == 7'b0000000) || (funct7 == 7'b0100000)) begin
                    case (funct3)
                        `INST_ADD_SUB: ex_ctrl_o = bit30 ? `EX_CTRL_SUB : `EX_CTRL_ADD;
                        `INST_SLL:     ex_ctrl_o = `EX_CTRL_SLL;
                        `INST_SLT:     ex_ctrl_o = `EX_CTRL_SLT;
                        `INST_SLTU:    ex_ctrl_o = `EX_CTRL_SLTU;
                        `INST_XOR:     ex_ctrl_o = `EX_CTRL_XOR;
                        `INST_SR:      ex_ctrl_o = bit30 ? `EX_CTRL_SRA : `EX_CTRL_SRL;
                        `INST_OR:      ex_ctrl_o = `EX_CTRL_OR;
                        `INST_AND:     ex_ctrl_o = `EX_CTRL_AND;
                        default:       ex_ctrl_o = `EX_CTRL_NOP;
                    endcase
                    if (ex_ctrl_o != `EX_CTRL_NOP) begin
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                    end
                end else if (funct7 == 7'b0000001) begin
                    case (funct3)
                        `INST_MUL:    ex_ctrl_o = `EX_CTRL_MUL;
                        `INST_MULH:   ex_ctrl_o = `EX_CTRL_MULH;
                        `INST_MULHSU: ex_ctrl_o = `EX_CTRL_MULHSU;
                        `INST_MULHU:  ex_ctrl_o = `EX_CTRL_MULHU;
                        `INST_DIV:    ex_ctrl_o = `EX_CTRL_DIV;
                        `INST_DIVU:   ex_ctrl_o = `EX_CTRL_DIVU;
                        `INST_REM:    ex_ctrl_o = `EX_CTRL_REM;
                        `INST_REMU:   ex_ctrl_o = `EX_CTRL_REMU;
                        default:      ex_ctrl_o = `EX_CTRL_NOP;
                    endcase
                    if (ex_ctrl_o != `EX_CTRL_NOP) begin
                        reg_we_o = ((funct3 == `INST_DIV) || (funct3 == `INST_DIVU) ||
                                    (funct3 == `INST_REM) || (funct3 == `INST_REMU)) ?
                                    `WriteDisable : `WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = rs2;
                        op1_o = reg1_rdata_i;
                        op2_o = reg2_rdata_i;
                        jump_addr_o = inst_addr_i + 32'h4;
                    end
                end
            end

            `INST_TYPE_L: begin
                case (funct3)
                    `INST_LB:  ex_ctrl_o = `EX_CTRL_LB;
                    `INST_LH:  ex_ctrl_o = `EX_CTRL_LH;
                    `INST_LW:  ex_ctrl_o = `EX_CTRL_LW;
                    `INST_LBU: ex_ctrl_o = `EX_CTRL_LBU;
                    `INST_LHU: ex_ctrl_o = `EX_CTRL_LHU;
                    default:   ex_ctrl_o = `EX_CTRL_NOP;
                endcase
                if (ex_ctrl_o != `EX_CTRL_NOP) begin
                    reg1_raddr_o = rs1;
                    reg2_raddr_o = `ZeroReg;
                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    op1_o = reg1_rdata_i;
                    op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                end
            end

            `INST_TYPE_S: begin
                case (funct3)
                    `INST_SB: ex_ctrl_o = `EX_CTRL_SB;
                    `INST_SH: ex_ctrl_o = `EX_CTRL_SH;
                    `INST_SW: ex_ctrl_o = `EX_CTRL_SW;
                    default:  ex_ctrl_o = `EX_CTRL_NOP;
                endcase
                if (ex_ctrl_o != `EX_CTRL_NOP) begin
                    reg1_raddr_o = rs1;
                    reg2_raddr_o = rs2;
                    reg_we_o = `WriteDisable;
                    reg_waddr_o = `ZeroReg;
                    op1_o = reg1_rdata_i;
                    op2_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};
                end
            end

            `INST_TYPE_B: begin
                case (funct3)
                    `INST_BEQ:  ex_ctrl_o = `EX_CTRL_BEQ;
                    `INST_BNE:  ex_ctrl_o = `EX_CTRL_BNE;
                    `INST_BLT:  ex_ctrl_o = `EX_CTRL_BLT;
                    `INST_BGE:  ex_ctrl_o = `EX_CTRL_BGE;
                    `INST_BLTU: ex_ctrl_o = `EX_CTRL_BLTU;
                    `INST_BGEU: ex_ctrl_o = `EX_CTRL_BGEU;
                    default:    ex_ctrl_o = `EX_CTRL_NOP;
                endcase
                if (ex_ctrl_o != `EX_CTRL_NOP) begin
                    reg1_raddr_o = rs1;
                    reg2_raddr_o = rs2;
                    reg_we_o = `WriteDisable;
                    reg_waddr_o = `ZeroReg;
                    op1_o = reg1_rdata_i;
                    op2_o = reg2_rdata_i;
                    jump_addr_o = inst_addr_i + {{20{inst_i[31]}}, inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};
                end
            end

            `INST_JAL: begin
                ex_ctrl_o = `EX_CTRL_JUMP;
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                jump_addr_o = inst_addr_i + {{12{inst_i[31]}}, inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};
            end

            `INST_JALR: begin
                ex_ctrl_o = `EX_CTRL_JUMP;
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                reg1_raddr_o = rs1;
                op1_o = inst_addr_i;
                op2_o = 32'h4;
                jump_addr_o = reg1_rdata_i + {{20{inst_i[31]}}, inst_i[31:20]};
            end

            `INST_LUI: begin
                ex_ctrl_o = `EX_CTRL_ADD;
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                op1_o = {inst_i[31:12], 12'b0};
                op2_o = `ZeroWord;
            end

            `INST_AUIPC: begin
                ex_ctrl_o = `EX_CTRL_ADD;
                reg_we_o = `WriteEnable;
                reg_waddr_o = rd;
                op1_o = inst_addr_i;
                op2_o = {inst_i[31:12], 12'b0};
            end

            `INST_NOP_OP: begin
                ex_ctrl_o = `EX_CTRL_NOP;
            end

            `INST_FENCE: begin
                ex_ctrl_o = `EX_CTRL_FENCE;
                jump_addr_o = inst_addr_i + 32'h4;
            end

            `INST_CSR: begin
                csr_raddr_o = {20'h0, inst_i[31:20]};
                csr_waddr_o = {20'h0, inst_i[31:20]};
                case (funct3)
                    `INST_CSRRW:  ex_ctrl_o = `EX_CTRL_CSRRW;
                    `INST_CSRRS:  ex_ctrl_o = `EX_CTRL_CSRRS;
                    `INST_CSRRC:  ex_ctrl_o = `EX_CTRL_CSRRC;
                    `INST_CSRRWI: ex_ctrl_o = `EX_CTRL_CSRRWI;
                    `INST_CSRRSI: ex_ctrl_o = `EX_CTRL_CSRRSI;
                    `INST_CSRRCI: ex_ctrl_o = `EX_CTRL_CSRRCI;
                    default:      ex_ctrl_o = `EX_CTRL_NOP;
                endcase
                if (ex_ctrl_o != `EX_CTRL_NOP) begin
                    reg_we_o = `WriteEnable;
                    reg_waddr_o = rd;
                    csr_we_o = `WriteEnable;
                    reg2_raddr_o = `ZeroReg;
                    if ((funct3 == `INST_CSRRW) || (funct3 == `INST_CSRRS) || (funct3 == `INST_CSRRC)) begin
                        reg1_raddr_o = rs1;
                        op1_o = reg1_rdata_i;
                    end else begin
                        reg1_raddr_o = `ZeroReg;
                        op1_o = {27'h0, rs1};
                    end
                end
            end

            `INST_SID: begin
                case (funct3)
                    `FUNCT3_SID: begin
                        ex_ctrl_o = `EX_CTRL_CUSTOM_SID;
                        reg_we_o = `WriteDisable;
                        reg_waddr_o = `ZeroReg;
                    end
                    `FUNCT3_RT: begin
                        ex_ctrl_o = `EX_CTRL_CUSTOM_RT;
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                    end
                    `FUNCT3_IF: begin
                        ex_ctrl_o = `EX_CTRL_CUSTOM_IF;
                        reg_we_o = `WriteEnable;
                        reg_waddr_o = rd;
                        reg1_raddr_o = rs1;
                        reg2_raddr_o = 5'd31;
                        op1_o = reg1_rdata_i;
                        op2_o = {{20{inst_i[31]}}, inst_i[31:20]};
                    end
                    default: begin
                        ex_ctrl_o = `EX_CTRL_NOP;
                    end
                endcase
            end

            default: begin
                ex_ctrl_o = `EX_CTRL_NOP;
            end
        endcase
    end

endmodule
