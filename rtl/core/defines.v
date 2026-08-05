 /*                                                                      
 Copyright 2019 Blue Liang, liangkangnan@163.com
                                                                         
 Licensed under the Apache License, Version 2.0 (the "License");         
 you may not use this file except in compliance with the License.        
 You may obtain a copy of the License at                                 
                                                                         
     http://www.apache.org/licenses/LICENSE-2.0                          
                                                                         
 Unless required by applicable law or agreed to in writing, software    
 distributed under the License is distributed on an "AS IS" BASIS,       
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and     
 limitations under the License.                                          
 */

`define CpuResetAddr 32'h0

`define RstEnable 1'b0
`define RstDisable 1'b1
`define ZeroWord 32'h0
`define ZeroReg 5'h0
`define WriteEnable 1'b1
`define WriteDisable 1'b0
`define ReadEnable 1'b1
`define ReadDisable 1'b0
`define True 1'b1
`define False 1'b0
`define ChipEnable 1'b1
`define ChipDisable 1'b0
`define JumpEnable 1'b1
`define JumpDisable 1'b0
`define HoldEnable 1'b1
`define HoldDisable 1'b0
`define Stop 1'b1
`define NoStop 1'b0
`define RIB_ACK 1'b1
`define RIB_NACK 1'b0
`define RIB_REQ 1'b1
`define RIB_NREQ 1'b0
`define INT_ASSERT 1'b1
`define INT_DEASSERT 1'b0

`define INT_BUS 7:0
`define INT_NONE 8'h0
`define INT_RET 8'hff
`define INT_TIMER0 8'b00000001
`define INT_TIMER0_ENTRY_ADDR 32'h4

`define Hold_Flag_Bus   2:0
`define Hold_None   3'b000
`define Hold_Pc     3'b001
`define Hold_If     3'b010
`define Hold_Id     3'b011
`define Hold_Freeze 3'b100

`define ExCtrlWidth 6
`define ExCtrlBus 5:0
`define EX_CTRL_NOP        6'd0
`define EX_CTRL_ADD        6'd1
`define EX_CTRL_SUB        6'd2
`define EX_CTRL_SLL        6'd3
`define EX_CTRL_SLT        6'd4
`define EX_CTRL_SLTU       6'd5
`define EX_CTRL_XOR        6'd6
`define EX_CTRL_SRL        6'd7
`define EX_CTRL_SRA        6'd8
`define EX_CTRL_OR         6'd9
`define EX_CTRL_AND        6'd10
`define EX_CTRL_REM        6'd17
`define EX_CTRL_REMU       6'd18
`define EX_CTRL_LB         6'd19
`define EX_CTRL_LH         6'd20
`define EX_CTRL_LW         6'd21
`define EX_CTRL_LBU        6'd22
`define EX_CTRL_LHU        6'd23
`define EX_CTRL_SB         6'd24
`define EX_CTRL_SH         6'd25
`define EX_CTRL_SW         6'd26
`define EX_CTRL_BEQ        6'd27
`define EX_CTRL_BNE        6'd28
`define EX_CTRL_BLT        6'd29
`define EX_CTRL_BGE        6'd30
`define EX_CTRL_BLTU       6'd31
`define EX_CTRL_BGEU       6'd32
`define EX_CTRL_JUMP       6'd33
`define EX_CTRL_FENCE      6'd34
`define EX_CTRL_CSRRW      6'd35
`define EX_CTRL_CSRRS      6'd36
`define EX_CTRL_CSRRC      6'd37
`define EX_CTRL_CSRRWI     6'd38
`define EX_CTRL_CSRRSI     6'd39
`define EX_CTRL_CSRRCI     6'd40
`define EX_CTRL_CUSTOM_SID 6'd41
`define EX_CTRL_CUSTOM_RT  6'd42
`define EX_CTRL_CUSTOM_IF  6'd43

// I type inst
`define INST_TYPE_I 7'b0010011
`define INST_ADDI   3'b000
`define INST_SLTI   3'b010
`define INST_SLTIU  3'b011
`define INST_XORI   3'b100
`define INST_ORI    3'b110
`define INST_ANDI   3'b111
`define INST_SLLI   3'b001
`define INST_SRI    3'b101

// L type inst
`define INST_TYPE_L 7'b0000011
`define INST_LB     3'b000
`define INST_LH     3'b001
`define INST_LW     3'b010
`define INST_LBU    3'b100
`define INST_LHU    3'b101

// S type inst
`define INST_TYPE_S 7'b0100011
`define INST_SB     3'b000
`define INST_SH     3'b001
`define INST_SW     3'b010

// R and M type inst
`define INST_TYPE_R_M 7'b0110011
// R type inst
`define INST_ADD_SUB 3'b000
`define INST_SLL    3'b001
`define INST_SLT    3'b010
`define INST_SLTU   3'b011
`define INST_XOR    3'b100
`define INST_SR     3'b101
`define INST_OR     3'b110
`define INST_AND    3'b111
// M type inst

// J type inst
`define INST_JAL    7'b1101111
`define INST_JALR   7'b1100111

`define INST_LUI    7'b0110111
`define INST_AUIPC  7'b0010111
`define INST_NOP    32'h00000001
`define INST_NOP_OP 7'b0000001
`define INST_MRET   32'h30200073
`define INST_RET    32'h00008067

`define INST_FENCE  7'b0001111
`define INST_ECALL  32'h73
`define INST_EBREAK 32'h00100073

// J type inst
`define INST_TYPE_B 7'b1100011
`define INST_BEQ    3'b000
`define INST_BNE    3'b001
`define INST_BLT    3'b100
`define INST_BGE    3'b101
`define INST_BLTU   3'b110
`define INST_BGEU   3'b111

// I2C debug: skip real bus, return 25C, delete after test
// `define I2C_DEBUG_LOOPBACK

// custom insts (opcode=0101111, shared with unused RV32A)
`define INST_SID    7'b0101111   // sID: funct3=000, send student ID via UART
`define FUNCT3_SID  3'b000
`define FUNCT3_RT   3'b001       // RT:  funct3=001, read LM75 temperature via I2C
`define FUNCT3_IF   3'b010       // IF:  funct3=010, integrate-and-fire neuron

// CSR inst
`define INST_CSR    7'b1110011
`define INST_CSRRW  3'b001
`define INST_CSRRS  3'b010
`define INST_CSRRC  3'b011
`define INST_CSRRWI 3'b101
`define INST_CSRRSI 3'b110
`define INST_CSRRCI 3'b111

// CSR reg addr
`define CSR_CYCLE   12'hc00
`define CSR_CYCLEH  12'hc80
`define CSR_MTVEC   12'h305
`define CSR_MCAUSE  12'h342
`define CSR_MEPC    12'h341
`define CSR_MIE     12'h304
`define CSR_MSTATUS 12'h300
`define CSR_MSCRATCH 12'h340

`define RomNum 4096  // rom depth(how many words)

`define MemNum 4096  // memory depth(how many words)
`define MemBus 31:0
`define MemAddrBus 31:0

`define InstBus 31:0
`define InstAddrBus 31:0

// common regs
`define RegAddrBus 4:0
`define RegBus 31:0
`define RegWidth 32
`define RegNum 32        // reg num
`define RegNumLog2 5
