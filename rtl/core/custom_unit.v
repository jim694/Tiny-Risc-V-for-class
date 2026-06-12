/*
 Copyright 2019 Blue Liang, liangkangnan@163.com
 Licensed under the Apache License, Version 2.0.
*/

`include "defines.v"

module custom_unit(

    input wire clk,
    input wire rst,

    input wire custom_valid_i,
    input wire[`ExCtrlBus] custom_op_i,
    input wire[`RegAddrBus] custom_rd_i,
    input wire[`RegBus] custom_op1_i,
    input wire[`RegBus] custom_op2_i,
    input wire[`RegBus] custom_reg2_rdata_i,

    input wire[`MemBus] mem_rdata_i,

    output reg custom_busy_o,
    output reg custom_done_o,
    output reg custom_reg_we_o,
    output reg[`RegAddrBus] custom_reg_waddr_o,
    output reg[`RegBus] custom_reg_wdata_o,

    output reg custom_mem_req_o,
    output reg custom_mem_we_o,
    output reg[`MemAddrBus] custom_mem_addr_o,
    output reg[`MemBus] custom_mem_wdata_o

    );

    localparam SID_N_WAIT = 13'd5000;
    localparam IF_N_WAIT  = 13'd5000;

    localparam RT_IDLE      = 4'd0;
    localparam RT_WR_CTRL_R = 4'd1;
    localparam RT_POLL_R    = 4'd2;
    localparam RT_RD        = 4'd3;

    wire custom_sid = custom_valid_i && (custom_op_i == `EX_CTRL_CUSTOM_SID);
    wire custom_rt  = custom_valid_i && (custom_op_i == `EX_CTRL_CUSTOM_RT);
    wire custom_if  = custom_valid_i && (custom_op_i == `EX_CTRL_CUSTOM_IF);
    wire if_integrate = custom_if && (custom_op2_i != `ZeroWord);
    wire if_no_fire = custom_if && (custom_op2_i == `ZeroWord) &&
                      (custom_op1_i < custom_reg2_rdata_i);
    wire if_fire_start = custom_if && (custom_op2_i == `ZeroWord) &&
                         (custom_op1_i >= custom_reg2_rdata_i);

    reg        sid_active;
    reg        sid_done;
    reg [3:0]  sid_byte_cnt;
    reg [12:0] sid_wait_cnt;
    reg [7:0]  sid_byte;

    reg        rt_active;
    reg        rt_done;
    reg [3:0]  rt_state;
    reg [4:0]  rt_rd_addr;
    reg [7:0]  rt_temp;

    reg        if_active;
    reg        if_done;
    reg [4:0]  if_rd_addr;
    reg [7:0]  if_byte;
    reg [12:0] if_wait_cnt;

    always @ (*) begin
        case (sid_byte_cnt)
            4'd0: sid_byte = 8'h32;
            4'd1: sid_byte = 8'h30;
            4'd2: sid_byte = 8'h32;
            4'd3: sid_byte = 8'h35;
            4'd4: sid_byte = 8'h32;
            4'd5: sid_byte = 8'h31;
            4'd6: sid_byte = 8'h30;
            4'd7: sid_byte = 8'h38;
            4'd8: sid_byte = 8'h36;
            default: sid_byte = 8'h30;
        endcase
    end

    always @ (*) begin
        custom_busy_o = `HoldDisable;
        custom_done_o = 1'b0;
        custom_reg_we_o = `WriteDisable;
        custom_reg_waddr_o = `ZeroReg;
        custom_reg_wdata_o = `ZeroWord;
        custom_mem_req_o = `RIB_NREQ;
        custom_mem_we_o = `WriteDisable;
        custom_mem_addr_o = `ZeroWord;
        custom_mem_wdata_o = `ZeroWord;

        if (custom_sid && !sid_done) begin
            custom_busy_o = `HoldEnable;
        end
        if (sid_done && custom_sid) begin
            custom_done_o = 1'b1;
        end
        if (sid_active) begin
            custom_busy_o = `HoldEnable;
            if (sid_wait_cnt == 13'h0) begin
                custom_mem_req_o = `RIB_REQ;
                custom_mem_we_o = `WriteEnable;
                custom_mem_addr_o = 32'h3000_000C;
                custom_mem_wdata_o = {24'h0, sid_byte};
            end
        end

        if (custom_rt && !rt_done) begin
            custom_busy_o = `HoldEnable;
        end
        if (rt_active) begin
            custom_busy_o = `HoldEnable;
            case (rt_state)
                RT_WR_CTRL_R: begin
                    custom_mem_req_o = `RIB_REQ;
                    custom_mem_we_o = `WriteEnable;
                    custom_mem_addr_o = 32'h7001_0000;
                    custom_mem_wdata_o = 32'h0000_05C8;
                end
                RT_POLL_R: begin
                    custom_mem_req_o = `RIB_REQ;
                    custom_mem_we_o = `WriteDisable;
                    custom_mem_addr_o = 32'h7001_0000;
                end
                RT_RD: begin
                    custom_mem_req_o = `RIB_REQ;
                    custom_mem_we_o = `WriteDisable;
                    custom_mem_addr_o = 32'h7003_0000;
                end
                default: begin
                    custom_mem_req_o = `RIB_NREQ;
                end
            endcase
        end
        if (rt_done && custom_rt) begin
            custom_done_o = 1'b1;
            custom_reg_we_o = `WriteEnable;
            custom_reg_waddr_o = rt_rd_addr;
            custom_reg_wdata_o = {24'h0, rt_temp};
        end

        if (if_integrate) begin
            custom_done_o = 1'b1;
            custom_reg_we_o = `WriteEnable;
            custom_reg_waddr_o = custom_rd_i;
            custom_reg_wdata_o = custom_op1_i + custom_op2_i;
        end else if (if_no_fire) begin
            custom_done_o = 1'b1;
            custom_reg_we_o = `WriteEnable;
            custom_reg_waddr_o = custom_rd_i;
            custom_reg_wdata_o = custom_op1_i;
        end else if (custom_if && !if_done) begin
            custom_busy_o = `HoldEnable;
        end
        if (if_active) begin
            custom_busy_o = `HoldEnable;
            if (if_wait_cnt == 13'h0) begin
                custom_mem_req_o = `RIB_REQ;
                custom_mem_we_o = `WriteEnable;
                custom_mem_addr_o = 32'h3000_000C;
                custom_mem_wdata_o = {24'h0, if_byte};
            end
        end
        if (if_done && custom_if) begin
            custom_done_o = 1'b1;
            custom_reg_we_o = `WriteEnable;
            custom_reg_waddr_o = if_rd_addr;
            custom_reg_wdata_o = `ZeroWord;
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            sid_active   <= 1'b0;
            sid_done     <= 1'b0;
            sid_byte_cnt <= 4'h0;
            sid_wait_cnt <= 13'h0;
        end else begin
            if (custom_sid && !sid_active && !sid_done) begin
                sid_active   <= 1'b1;
                sid_byte_cnt <= 4'h0;
                sid_wait_cnt <= 13'h0;
            end else if (sid_active) begin
                if (sid_wait_cnt == SID_N_WAIT) begin
                    sid_wait_cnt <= 13'h0;
                    if (sid_byte_cnt == 4'd9) begin
                        sid_active <= 1'b0;
                        sid_done   <= 1'b1;
                    end else begin
                        sid_byte_cnt <= sid_byte_cnt + 1'b1;
                    end
                end else begin
                    sid_wait_cnt <= sid_wait_cnt + 1'b1;
                end
            end else begin
                if (!custom_sid)
                    sid_done <= 1'b0;
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            rt_active  <= 1'b0;
            rt_done    <= 1'b0;
            rt_state   <= RT_IDLE;
            rt_rd_addr <= 5'h0;
            rt_temp    <= 8'h0;
        end else begin
            if (custom_rt && !rt_active && !rt_done) begin
                rt_active  <= 1'b1;
                rt_rd_addr <= custom_rd_i;
                rt_state   <= RT_WR_CTRL_R;
            end else if (rt_active) begin
                case (rt_state)
                    RT_WR_CTRL_R: rt_state <= RT_POLL_R;
                    RT_POLL_R:    rt_state <= (mem_rdata_i[9] == 1'b0) ? RT_RD : RT_POLL_R;
                    RT_RD: begin
                        rt_temp   <= mem_rdata_i[14:7];
                        rt_active <= 1'b0;
                        rt_done   <= 1'b1;
                        rt_state  <= RT_IDLE;
                    end
                    default: rt_state <= RT_IDLE;
                endcase
            end else begin
                if (!custom_rt)
                    rt_done <= 1'b0;
            end
        end
    end

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            if_active   <= 1'b0;
            if_done     <= 1'b0;
            if_rd_addr  <= 5'h0;
            if_byte     <= 8'h0;
            if_wait_cnt <= 13'h0;
        end else begin
            if (if_fire_start && !if_active && !if_done) begin
                if_active   <= 1'b1;
                if_rd_addr  <= custom_rd_i;
                if_byte     <= custom_op1_i[7:0];
                if_wait_cnt <= 13'h0;
            end else if (if_active) begin
                if (if_wait_cnt == IF_N_WAIT) begin
                    if_active   <= 1'b0;
                    if_done     <= 1'b1;
                    if_wait_cnt <= 13'h0;
                end else begin
                    if_wait_cnt <= if_wait_cnt + 13'h1;
                end
            end else begin
                if (!custom_if)
                    if_done <= 1'b0;
            end
        end
    end

endmodule
