/* IF/ID pipeline register. */
`include "defines.v"

module if_id(
    input wire clk,
    input wire rst,
    input wire[`InstBus] inst_i,
    input wire[`InstAddrBus] inst_addr_i,
    input wire[`Hold_Flag_Bus] hold_flag_i,
    output wire[`InstBus] inst_o,
    output wire[`InstAddrBus] inst_addr_o
    );

    wire flush_en  = (hold_flag_i == `Hold_If || hold_flag_i == `Hold_Id);
    wire freeze_en = (hold_flag_i == `Hold_Freeze);

    wire[`InstBus] inst;
    gen_pipe_dff #(32) inst_ff(clk, rst, flush_en, freeze_en, `INST_NOP, inst_i, inst);
    assign inst_o = inst;

    wire[`InstAddrBus] inst_addr;
    gen_pipe_dff #(32) inst_addr_ff(clk, rst, flush_en, freeze_en, `ZeroWord, inst_addr_i, inst_addr);
    assign inst_addr_o = inst_addr;

endmodule
