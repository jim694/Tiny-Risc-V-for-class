`timescale 1ns/1ps

// Four-core mutually exclusive resource selector.
// chip_sel_i is decoded only at the integration boundary:
// 000..011 select core 0..3; all other values select no core.
module core_select(
    input wire [2:0] chip_sel_i,

    // Core-to-shared register-file request buses, slot 0 at the least
    // significant slice.
    input wire [4*5-1:0] rf_raddr1_i,
    input wire [4*5-1:0] rf_raddr2_i,
    input wire [3:0] rf_we_i,
    input wire [4*5-1:0] rf_waddr_i,
    input wire [4*32-1:0] rf_wdata_i,

    // Shared register-file read response.
    input wire [31:0] rf_rdata1_i,
    input wire [31:0] rf_rdata2_i,

    input wire [4*32-1:0] ibus_addr_i,
    input wire [31:0] ibus_data_i,
    input wire [4*32-1:0] dbus_addr_i,
    input wire [4*32-1:0] dbus_wdata_i,
    input wire [3:0] dbus_req_i,
    input wire [3:0] dbus_we_i,
    input wire [31:0] dbus_rdata_i,
    input wire dbus_hold_i,

    output reg [3:0] selected_o,
    output reg [4:0] rf_raddr1_o,
    output reg [4:0] rf_raddr2_o,
    output reg rf_we_o,
    output reg [4:0] rf_waddr_o,
    output reg [31:0] rf_wdata_o,

    // Shared response is returned only to the selected slot.
    output reg [4*32-1:0] rf_rdata1_o,
    output reg [4*32-1:0] rf_rdata2_o,

    output reg [31:0] ibus_addr_o,
    output reg [4*32-1:0] ibus_data_o,
    output reg [31:0] dbus_addr_o,
    output reg [31:0] dbus_wdata_o,
    output reg dbus_req_o,
    output reg dbus_we_o,
    output reg [4*32-1:0] dbus_rdata_o,
    output reg [3:0] dbus_hold_o
    );

    always @ (*) begin
        selected_o = 4'b0000;
        rf_raddr1_o = 5'b0;
        rf_raddr2_o = 5'b0;
        rf_we_o = 1'b0;
        rf_waddr_o = 5'b0;
        rf_wdata_o = 32'b0;
        rf_rdata1_o = 128'b0;
        rf_rdata2_o = 128'b0;
        ibus_addr_o = 32'b0;
        ibus_data_o = 128'b0;
        dbus_addr_o = 32'b0;
        dbus_wdata_o = 32'b0;
        dbus_req_o = 1'b0;
        dbus_we_o = 1'b0;
        dbus_rdata_o = 128'b0;
        dbus_hold_o = 4'b0000;

        case (chip_sel_i)
            3'b000: begin
                selected_o = 4'b0001;
                rf_raddr1_o = rf_raddr1_i[4:0];
                rf_raddr2_o = rf_raddr2_i[4:0];
                rf_we_o = rf_we_i[0];
                rf_waddr_o = rf_waddr_i[4:0];
                rf_wdata_o = rf_wdata_i[31:0];
                rf_rdata1_o[31:0] = rf_rdata1_i;
                rf_rdata2_o[31:0] = rf_rdata2_i;
                ibus_addr_o = ibus_addr_i[31:0];
                ibus_data_o[31:0] = ibus_data_i;
                dbus_addr_o = dbus_addr_i[31:0];
                dbus_wdata_o = dbus_wdata_i[31:0];
                dbus_req_o = dbus_req_i[0];
                dbus_we_o = dbus_we_i[0];
                dbus_rdata_o[31:0] = dbus_rdata_i;
                dbus_hold_o[0] = dbus_hold_i;
            end
            3'b001: begin
                selected_o = 4'b0010;
                rf_raddr1_o = rf_raddr1_i[9:5];
                rf_raddr2_o = rf_raddr2_i[9:5];
                rf_we_o = rf_we_i[1];
                rf_waddr_o = rf_waddr_i[9:5];
                rf_wdata_o = rf_wdata_i[63:32];
                rf_rdata1_o[63:32] = rf_rdata1_i;
                rf_rdata2_o[63:32] = rf_rdata2_i;
                ibus_addr_o = ibus_addr_i[63:32];
                ibus_data_o[63:32] = ibus_data_i;
                dbus_addr_o = dbus_addr_i[63:32];
                dbus_wdata_o = dbus_wdata_i[63:32];
                dbus_req_o = dbus_req_i[1];
                dbus_we_o = dbus_we_i[1];
                dbus_rdata_o[63:32] = dbus_rdata_i;
                dbus_hold_o[1] = dbus_hold_i;
            end
            3'b010: begin
                selected_o = 4'b0100;
                rf_raddr1_o = rf_raddr1_i[14:10];
                rf_raddr2_o = rf_raddr2_i[14:10];
                rf_we_o = rf_we_i[2];
                rf_waddr_o = rf_waddr_i[14:10];
                rf_wdata_o = rf_wdata_i[95:64];
                rf_rdata1_o[95:64] = rf_rdata1_i;
                rf_rdata2_o[95:64] = rf_rdata2_i;
                ibus_addr_o = ibus_addr_i[95:64];
                ibus_data_o[95:64] = ibus_data_i;
                dbus_addr_o = dbus_addr_i[95:64];
                dbus_wdata_o = dbus_wdata_i[95:64];
                dbus_req_o = dbus_req_i[2];
                dbus_we_o = dbus_we_i[2];
                dbus_rdata_o[95:64] = dbus_rdata_i;
                dbus_hold_o[2] = dbus_hold_i;
            end
            3'b011: begin
                selected_o = 4'b1000;
                rf_raddr1_o = rf_raddr1_i[19:15];
                rf_raddr2_o = rf_raddr2_i[19:15];
                rf_we_o = rf_we_i[3];
                rf_waddr_o = rf_waddr_i[19:15];
                rf_wdata_o = rf_wdata_i[127:96];
                rf_rdata1_o[127:96] = rf_rdata1_i;
                rf_rdata2_o[127:96] = rf_rdata2_i;
                ibus_addr_o = ibus_addr_i[127:96];
                ibus_data_o[127:96] = ibus_data_i;
                dbus_addr_o = dbus_addr_i[127:96];
                dbus_wdata_o = dbus_wdata_i[127:96];
                dbus_req_o = dbus_req_i[3];
                dbus_we_o = dbus_we_i[3];
                dbus_rdata_o[127:96] = dbus_rdata_i;
                dbus_hold_o[3] = dbus_hold_i;
            end
            default: begin
                // Invalid selections deliberately leave every shared port idle.
            end
        endcase
    end
endmodule
