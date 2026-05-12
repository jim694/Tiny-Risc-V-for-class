`include "defines.v"

// SoC侧存储器桥接模块（7状态FSM，8周期/事务）
//
// 优化：原 S_SEND_CTRL 状态已合并入 S_IDLE。
//   pending=1 时 CPU 已被 Hold_Freeze 冻住，地址稳定，可在 S_IDLE 直接捕获并发出 CTRL。
//
// 采样对齐（以读ROM[0]为例，T=0为S_IDLE pending拍）：
//   T+0: S_IDLE    → ext_out=CTRL
//   T+1: S_SEND_ADDR → ext_out=ADDR；FPGA收CTRL→S_RECV_ADDR
//   T+2: S_DATA0   → FPGA收ADDR，读存储体，ext_out(FPGA)=rdata[7:0]
//   T+3: S_DATA1   → SoC采rdata[7:0]
//   T+4: S_DATA2   → SoC采rdata[15:8]
//   T+5: S_DATA3   → SoC采rdata[23:16]
//   T+6: S_LATCH   → SoC采rdata[31:24]，锁存，stall释放
//   T+7: S_IDLE free cycle → CPU推进
//
// Hold_Freeze 保证事务期间 PC 不变，addr_match 不再需要。
module rib_mem_bridge (
    input  wire        clk,
    input  wire        rst,

    // RIB Slave 0（ROM，0x0xxx_xxxx）
    input  wire [31:0] s0_addr_i,
    input  wire [31:0] s0_wdata_i,
    output reg  [31:0] s0_rdata_o,
    input  wire        s0_we_i,
    input  wire        s0_cs_i,

    // RIB Slave 1（RAM，0x1xxx_xxxx）
    input  wire [31:0] s1_addr_i,
    input  wire [31:0] s1_wdata_i,
    output reg  [31:0] s1_rdata_o,
    input  wire        s1_we_i,
    input  wire        s1_cs_i,

    // 8-bit 串行外部接口
    output reg  [7:0]  ext_out_o,
    input  wire [7:0]  ext_in_i,

    // CPU 流水线暂停
    output wire        stall_o
);

    localparam S_IDLE      = 3'd0;
    localparam S_SEND_ADDR = 3'd1;
    localparam S_DATA0     = 3'd2;
    localparam S_DATA1     = 3'd3;
    localparam S_DATA2     = 3'd4;
    localparam S_DATA3     = 3'd5;
    localparam S_LATCH     = 3'd6;

    reg [2:0]  state;
    reg        transaction_done;
    reg        mem_sel_r;
    reg [7:0]  addr_r;
    reg        we_r;
    reg [31:0] wdata_r;
    reg [23:0] rdata_buf;

    wire any_cs  = s0_cs_i || s1_cs_i;
    wire pending = any_cs && (state == S_IDLE) && !transaction_done;

    assign stall_o = (state != S_IDLE) || pending;

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state            <= S_IDLE;
            transaction_done <= 1'b0;
            ext_out_o        <= 8'h0;
            s0_rdata_o       <= `ZeroWord;
            s1_rdata_o       <= `ZeroWord;
            mem_sel_r        <= 1'b0;
            addr_r           <= 8'h0;
            we_r             <= 1'b0;
            wdata_r          <= `ZeroWord;
            rdata_buf        <= 24'h0;
        end else begin
            transaction_done <= 1'b0;

            case (state)
                // pending=1 时 CPU 已冻住，地址稳定：直接捕获并发出 CTRL
                S_IDLE: begin
                    if (any_cs && !transaction_done) begin
                        mem_sel_r <= s1_cs_i;
                        addr_r    <= s1_cs_i ? s1_addr_i[9:2] : s0_addr_i[9:2];
                        we_r      <= s1_cs_i ? s1_we_i   : s0_we_i;
                        wdata_r   <= s1_cs_i ? s1_wdata_i : s0_wdata_i;
                        ext_out_o <= {1'b1, s1_cs_i,
                                      (s1_cs_i ? s1_we_i : s0_we_i),
                                      5'b0};
                        state     <= S_SEND_ADDR;
                    end else begin
                        ext_out_o <= 8'h0;
                    end
                end

                S_SEND_ADDR: begin
                    ext_out_o <= addr_r;
                    state     <= S_DATA0;
                end

                // FPGA 此拍收到 ADDR，读存储体，下一拍输出 rdata[7:0]
                S_DATA0: begin
                    ext_out_o <= wdata_r[7:0];
                    state     <= S_DATA1;
                end

                // 采 rdata[7:0]
                S_DATA1: begin
                    ext_out_o      <= wdata_r[15:8];
                    rdata_buf[7:0] <= ext_in_i;
                    state          <= S_DATA2;
                end

                // 采 rdata[15:8]
                S_DATA2: begin
                    ext_out_o       <= wdata_r[23:16];
                    rdata_buf[15:8] <= ext_in_i;
                    state           <= S_DATA3;
                end

                // 采 rdata[23:16]
                S_DATA3: begin
                    ext_out_o        <= wdata_r[31:24];
                    rdata_buf[23:16] <= ext_in_i;
                    state            <= S_LATCH;
                end

                // 采 rdata[31:24]，锁存完整数据
                // Hold_Freeze 保证事务期间 PC 不变，无需 addr_match
                S_LATCH: begin
                    ext_out_o <= 8'h0;
                    if (mem_sel_r)
                        s1_rdata_o <= {ext_in_i, rdata_buf};
                    else
                        s0_rdata_o <= {ext_in_i, rdata_buf};
                    transaction_done <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
