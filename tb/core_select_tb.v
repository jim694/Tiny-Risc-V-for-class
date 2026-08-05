`timescale 1ns/1ps

module core_select_tb;

    reg [2:0] chip_sel_i;
    reg [4*5-1:0] rf_raddr1_i;
    reg [4*5-1:0] rf_raddr2_i;
    reg [31:0] rf_rdata1_i;
    reg [31:0] rf_rdata2_i;
    reg [3:0] rf_we_i;
    reg [4*5-1:0] rf_waddr_i;
    reg [4*32-1:0] rf_wdata_i;
    reg [4*32-1:0] ibus_addr_i;
    reg [31:0] ibus_data_i;
    reg [4*32-1:0] dbus_addr_i;
    reg [4*32-1:0] dbus_wdata_i;
    reg [3:0] dbus_req_i;
    reg [3:0] dbus_we_i;
    reg [31:0] dbus_rdata_i;
    reg dbus_hold_i;
    wire [3:0] selected_o;
    wire [4:0] rf_raddr1_o;
    wire [4:0] rf_raddr2_o;
    wire [4*32-1:0] rf_rdata1_o;
    wire [4*32-1:0] rf_rdata2_o;
    wire rf_we_o;
    wire [4:0] rf_waddr_o;
    wire [31:0] rf_wdata_o;
    wire [31:0] ibus_addr_o;
    wire [4*32-1:0] ibus_data_o;
    wire [31:0] dbus_addr_o;
    wire [31:0] dbus_wdata_o;
    wire dbus_req_o;
    wire dbus_we_o;
    wire [4*32-1:0] dbus_rdata_o;
    wire [3:0] dbus_hold_o;

    core_select dut (
        .chip_sel_i(chip_sel_i),
        .rf_raddr1_i(rf_raddr1_i),
        .rf_raddr2_i(rf_raddr2_i),
        .rf_rdata1_i(rf_rdata1_i),
        .rf_rdata2_i(rf_rdata2_i),
        .rf_we_i(rf_we_i),
        .rf_waddr_i(rf_waddr_i),
        .rf_wdata_i(rf_wdata_i),
        .selected_o(selected_o),
        .rf_raddr1_o(rf_raddr1_o),
        .rf_raddr2_o(rf_raddr2_o),
        .rf_rdata1_o(rf_rdata1_o),
        .rf_rdata2_o(rf_rdata2_o),
        .rf_we_o(rf_we_o),
        .rf_waddr_o(rf_waddr_o),
        .rf_wdata_o(rf_wdata_o)
        ,.ibus_addr_i(ibus_addr_i)
        ,.ibus_data_i(ibus_data_i)
        ,.ibus_addr_o(ibus_addr_o)
        ,.ibus_data_o(ibus_data_o)
        ,.dbus_addr_i(dbus_addr_i)
        ,.dbus_wdata_i(dbus_wdata_i)
        ,.dbus_req_i(dbus_req_i)
        ,.dbus_we_i(dbus_we_i)
        ,.dbus_rdata_i(dbus_rdata_i)
        ,.dbus_hold_i(dbus_hold_i)
        ,.dbus_addr_o(dbus_addr_o)
        ,.dbus_wdata_o(dbus_wdata_o)
        ,.dbus_req_o(dbus_req_o)
        ,.dbus_we_o(dbus_we_o)
        ,.dbus_rdata_o(dbus_rdata_o)
        ,.dbus_hold_o(dbus_hold_o)
    );

    task check_selection;
        input [2:0] sel;
        input [3:0] expected_selected;
        input [4:0] expected_addr;
        input [4*32-1:0] expected_data;
        input [4*32-1:0] expected_data2;
        input expected_we;
        input [4:0] expected_waddr;
        input [31:0] expected_wdata;
        input [31:0] expected_ibus_addr;
        input [4*32-1:0] expected_ibus_data;
        input [31:0] expected_dbus_addr;
        input [4*32-1:0] expected_dbus_data;
        input [3:0] expected_hold;
        begin
            chip_sel_i = sel;
            #1;
            if (selected_o !== expected_selected || rf_raddr1_o !== expected_addr ||
                rf_rdata1_o !== expected_data || rf_rdata2_o !== expected_data2 ||
                rf_we_o !== expected_we || rf_waddr_o !== expected_waddr ||
                rf_wdata_o !== expected_wdata || ibus_addr_o !== expected_ibus_addr ||
                ibus_data_o !== expected_ibus_data || dbus_addr_o !== expected_dbus_addr ||
                dbus_rdata_o !== expected_dbus_data || dbus_hold_o !== expected_hold) begin
                $display("FAIL sel=%b selected=%b raddr=%h we=%b waddr=%h wdata=%h",
                         sel, selected_o, rf_raddr1_o, rf_we_o, rf_waddr_o, rf_wdata_o);
                $finish(1);
            end
        end
    endtask

    initial begin
        rf_raddr1_i = {5'd4, 5'd3, 5'd2, 5'd1};
        rf_raddr2_i = {5'd14, 5'd13, 5'd12, 5'd11};
        rf_rdata1_i = 32'haaaa_0000;
        rf_rdata2_i = 32'hbbbb_0000;
        rf_we_i = 4'b1010;
        rf_waddr_i = {5'd24, 5'd23, 5'd22, 5'd21};
        rf_wdata_i = {32'h4444_aaaa, 32'h3333_aaaa, 32'h2222_aaaa, 32'h1111_aaaa};
        ibus_addr_i = {32'h0000_0040, 32'h0000_0030, 32'h0000_0020, 32'h0000_0010};
        ibus_data_i = 32'h1234_5678;
        dbus_addr_i = {32'h1000_0040, 32'h1000_0030, 32'h1000_0020, 32'h1000_0010};
        dbus_wdata_i = {32'hd000_0004, 32'hd000_0003, 32'hd000_0002, 32'hd000_0001};
        dbus_req_i = 4'b1111;
        dbus_we_i = 4'b1010;
        dbus_rdata_i = 32'h89ab_cdef;
        dbus_hold_i = 1'b1;

        check_selection(3'b000, 4'b0001, 5'd1,
                        {96'd0, 32'haaaa_0000}, {96'd0, 32'hbbbb_0000},
                        1'b0, 5'd21, 32'h1111_aaaa,
                        32'h0000_0010, {96'd0, 32'h1234_5678},
                        32'h1000_0010, {96'd0, 32'h89ab_cdef}, 4'b0001);
        check_selection(3'b001, 4'b0010, 5'd2,
                        {64'd0, 32'haaaa_0000, 32'd0}, {64'd0, 32'hbbbb_0000, 32'd0},
                        1'b1, 5'd22, 32'h2222_aaaa,
                        32'h0000_0020, {64'd0, 32'h1234_5678, 32'd0},
                        32'h1000_0020, {64'd0, 32'h89ab_cdef, 32'd0}, 4'b0010);
        check_selection(3'b010, 4'b0100, 5'd3,
                        {32'd0, 32'haaaa_0000, 64'd0}, {32'd0, 32'hbbbb_0000, 64'd0},
                        1'b0, 5'd23, 32'h3333_aaaa,
                        32'h0000_0030, {32'd0, 32'h1234_5678, 64'd0},
                        32'h1000_0030, {32'd0, 32'h89ab_cdef, 64'd0}, 4'b0100);
        check_selection(3'b011, 4'b1000, 5'd4,
                        {32'haaaa_0000, 96'd0}, {32'hbbbb_0000, 96'd0},
                        1'b1, 5'd24, 32'h4444_aaaa,
                        32'h0000_0040, {32'h1234_5678, 96'd0},
                        32'h1000_0040, {32'h89ab_cdef, 96'd0}, 4'b1000);
        check_selection(3'b100, 4'b0000, 5'd0, 128'd0, 128'd0,
                        1'b0, 5'd0, 32'd0,
                        32'd0, 128'd0, 32'd0, 128'd0, 4'b0000);
        check_selection(3'b111, 4'b0000, 5'd0, 128'd0, 128'd0,
                        1'b0, 5'd0, 32'd0,
                        32'd0, 128'd0, 32'd0, 128'd0, 4'b0000);
        $display("PASS core_select");
        $finish(0);
    end
endmodule
