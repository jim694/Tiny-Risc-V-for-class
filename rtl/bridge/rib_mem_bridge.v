`include "defines.v"

// SoC侧存储器桥接模块（8状态FSM）
//
// taken branch 处理：
//   branch 执行时 PC 跳转（Hold_Id 允许 PC 更新），但 bridge 仍在为顺序地址做事务。
//   在 S_LATCH 中比对 s0_addr_i[9:2]（当前 PC）与 addr_r（事务地址）：
//     地址匹配  → 正常锁存，置 transaction_done=1（给 1 拍 free cycle 推进 PC）
//     地址不匹配 → 不锁存，不置 transaction_done → S_IDLE 立即再发起正确地址的事务
//
// 采样对齐（以读ROM[0]为例）：
//   after T+3: FPGA 输出 rdata[7:0]  → SoC 在 S_DATA1(T+4) 采样
//   after T+4: FPGA 输出 rdata[15:8] → SoC 在 S_DATA2(T+5) 采样
//   after T+5: FPGA 输出 rdata[23:16]→ SoC 在 S_DATA3(T+6) 采样
//   after T+6: FPGA 输出 rdata[31:24]→ SoC 在 S_LATCH(T+7) 采样并锁存
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
    localparam S_SEND_CTRL = 3'd1;
    localparam S_SEND_ADDR = 3'd2;
    localparam S_DATA0     = 3'd3;
    localparam S_DATA1     = 3'd4;
    localparam S_DATA2     = 3'd5;
    localparam S_DATA3     = 3'd6;
    localparam S_LATCH     = 3'd7;

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

    // 在 S_LATCH 时检测是否发生了 taken branch（PC 改变）
    // 若地址不匹配则放弃本次数据，触发立即重新事务
    wire [7:0] cur_word_addr = mem_sel_r ? s1_addr_i[9:2] : s0_addr_i[9:2];
    wire addr_match = (cur_word_addr == addr_r);

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
                S_IDLE: begin
                    ext_out_o <= 8'h0;
                    if (any_cs && !transaction_done)
                        state <= S_SEND_CTRL;
                end

                // CPU 已被 pending 冻住，s0_addr_i 稳定，捕获地址
                S_SEND_CTRL: begin
                    mem_sel_r <= s1_cs_i;
                    addr_r    <= s1_cs_i ? s1_addr_i[9:2] : s0_addr_i[9:2];
                    we_r      <= s1_cs_i ? s1_we_i   : s0_we_i;
                    wdata_r   <= s1_cs_i ? s1_wdata_i : s0_wdata_i;
                    ext_out_o <= {1'b1, s1_cs_i,
                                  (s1_cs_i ? s1_we_i : s0_we_i),
                                  5'b0};
                    state     <= S_SEND_ADDR;
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

                // 采 rdata[7:0]（FPGA S_RECV_ADDR 的输出）
                S_DATA1: begin
                    ext_out_o     <= wdata_r[15:8];
                    rdata_buf[7:0]<= ext_in_i;
                    state         <= S_DATA2;
                end

                // 采 rdata[15:8]（FPGA S_DATA0 的输出）
                S_DATA2: begin
                    ext_out_o      <= wdata_r[23:16];
                    rdata_buf[15:8]<= ext_in_i;
                    state          <= S_DATA3;
                end

                // 采 rdata[23:16]（FPGA S_DATA1 的输出）
                S_DATA3: begin
                    ext_out_o       <= wdata_r[31:24];
                    rdata_buf[23:16]<= ext_in_i;
                    state           <= S_LATCH;
                end

                // 采 rdata[31:24]；检测 branch 跳转
                S_LATCH: begin
                    ext_out_o <= 8'h0;
                    if (addr_match) begin
                        // 地址匹配：正常锁存，授予 1 拍 free cycle
                        if (mem_sel_r)
                            s1_rdata_o <= {ext_in_i, rdata_buf};
                        else
                            s0_rdata_o <= {ext_in_i, rdata_buf};
                        transaction_done <= 1'b1;
                    end
                    // 地址不匹配（taken branch 改变了 PC）：
                    //   不锁存数据，不置 transaction_done
                    //   → S_IDLE 立即 pending=1 → 为正确目标地址重新发起事务
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
