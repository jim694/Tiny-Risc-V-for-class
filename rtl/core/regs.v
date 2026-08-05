/* Shared RV32 register file: two combinational reads and one clocked write. */
`include "defines.v"

module regs(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[`RegAddrBus] waddr_i,
    input wire[`RegBus] wdata_i,
    input wire[`RegAddrBus] raddr1_i,
    output reg[`RegBus] rdata1_o,
    input wire[`RegAddrBus] raddr2_i,
    output reg[`RegBus] rdata2_o
    );

    reg[`RegBus] regs[0:`RegNum - 1];

    always @ (posedge clk) begin
        if (rst == `RstDisable && we_i == `WriteEnable && waddr_i != `ZeroReg) begin
            regs[waddr_i] <= wdata_i;
        end
    end

    always @ (*) begin
        if (raddr1_i == `ZeroReg) begin
            rdata1_o = `ZeroWord;
        end else if (raddr1_i == waddr_i && we_i == `WriteEnable) begin
            rdata1_o = wdata_i;
        end else begin
            rdata1_o = regs[raddr1_i];
        end
    end

    always @ (*) begin
        if (raddr2_i == `ZeroReg) begin
            rdata2_o = `ZeroWord;
        end else if (raddr2_i == waddr_i && we_i == `WriteEnable) begin
            rdata2_o = wdata_i;
        end else begin
            rdata2_o = regs[raddr2_i];
        end
    end

endmodule
