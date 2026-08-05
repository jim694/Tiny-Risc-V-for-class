`timescale 1ns/1ps

module vio_smoke_top(
    input wire clk,
    output wire [2:0] chip_sel_o,
    output wire [3:0] selected_o
    );

    wire [3:0] selected = (chip_sel_o < 3'd4) ? (4'b0001 << chip_sel_o) : 4'b0000;
    wire [31:0] status_counter;

    vio_0 u_vio(
        .clk(clk),
        .probe_in0(selected),
        .probe_in1(status_counter),
        .probe_out0(chip_sel_o)
    );

    assign selected_o = selected;

    reg [31:0] counter;
    always @ (posedge clk) begin
        counter <= counter + 32'd1;
    end
    assign status_counter = counter;

endmodule
