`include "../core/defines.v"

// SoC侧存储器桥接模块（7状态FSM，8周期/事务）
//
// 设计原则：
//   bridge 只通过 RIB 从设备接口（s0/s1）感知外部世界，无飞线。
//
//   关键支撑：rib.v 将 s0_addr_o 的默认值设为 m1_addr_i（PC），
//   因此当 m0 占总线访问非 bridge slave（如 PWM）时：
//     s0_cs_i=0, s1_cs_i=0, s0_addr_i = m1_addr_i = 冻结 PC
//   bridge 可在 S_IDLE 直接用 s0_addr_i 发起 ROM 取指，无需额外输入。
//
// Stall 策略：
//   bridge 在 S_IDLE 且非自由拍（!transaction_done）时始终发起事务：
//     - need_fetch_r=1：RAM 事务后强制 ROM 取指
//     - s1_cs_i=1    ：RAM 数据访问
//     - 其他         ：ROM 取指（instruction fetch 或 forced fetch）
//   stall_o = (state != S_IDLE) || !transaction_done
//
// addr_match：
//   ROM 事务用 s0_addr_i[9:2]（= PC，来自 RIB 默认，m0 占总线时仍有效）
//   RAM 事务用 s1_addr_i[9:2]（数据地址，m0 占总线时有效）
//
// 采样对齐（T=0 为 S_IDLE 启动拍）：
//   T+0: S_IDLE    → ext_out=CTRL
//   T+1: S_SEND_ADDR → ext_out=ADDR
//   T+2: S_DATA0   → FPGA读存储体
//   T+3: S_DATA1   → SoC采rdata[7:0]
//   T+4: S_DATA2   → SoC采rdata[15:8]
//   T+5: S_DATA3   → SoC采rdata[23:16]
//   T+6: S_LATCH   → SoC采rdata[31:24]，锁存
//   T+7: 自由拍    → CPU推进
module rib_mem_bridge (
    input  wire        clk,
    input  wire        rst,

    // RIB Slave 0（ROM，0x0xxx_xxxx）
    input  wire [31:0] s0_addr_i,   // 由 RIB 驱动；默认=m1_addr_i(PC)
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
    reg        need_fetch_r;   // RAM 事务后待强制 ROM 取指
    reg        mem_sel_r;      // 0=ROM, 1=RAM
    reg [7:0]  addr_r;
    reg        we_r;
    reg [31:0] wdata_r;
    reg [23:0] rdata_buf;

    // bridge 在 S_IDLE 且非自由拍时始终发起事务
    assign stall_o = (state != S_IDLE) || !transaction_done;

    // addr_match：ROM 用 s0_addr_i（RIB 默认=PC），RAM 用 s1_addr_i
    wire [7:0] cur_word_addr = mem_sel_r ? s1_addr_i[9:2] : s0_addr_i[9:2];
    wire addr_match = (cur_word_addr == addr_r);

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state            <= S_IDLE;
            transaction_done <= 1'b0;
            need_fetch_r     <= 1'b0;
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
                // bridge 始终发起事务，优先级：need_fetch_r > RAM > ROM
                S_IDLE: begin
                    if (!transaction_done) begin
                        if (need_fetch_r) begin
                            // RAM 事务后强制取指：s0_addr_i = PC（RIB 默认）
                            mem_sel_r <= 1'b0;
                            addr_r    <= s0_addr_i[9:2];
                            we_r      <= 1'b0;
                            wdata_r   <= `ZeroWord;
                            ext_out_o <= {1'b1, 1'b0, 1'b0, 5'b0};
                            state     <= S_SEND_ADDR;
                        end else if (s1_cs_i) begin
                            // RAM 数据访问（m0 lw/sw）
                            mem_sel_r <= 1'b1;
                            addr_r    <= s1_addr_i[9:2];
                            we_r      <= s1_we_i;
                            wdata_r   <= s1_wdata_i;
                            ext_out_o <= {1'b1, 1'b1, s1_we_i, 5'b0};
                            state     <= S_SEND_ADDR;
                        end else begin
                            // ROM 取指：s0_cs_i=1（显式请求）或 =0（m0 占总线时隐式）
                            // 两种情况下 s0_addr_i 均 = PC（RIB 默认 m1_addr_i）
                            mem_sel_r <= 1'b0;
                            addr_r    <= s0_addr_i[9:2];
                            we_r      <= s0_we_i;
                            wdata_r   <= s0_wdata_i;
                            ext_out_o <= {1'b1, 1'b0, s0_we_i, 5'b0};
                            state     <= S_SEND_ADDR;
                        end
                    end else begin
                        ext_out_o <= 8'h0;
                    end
                end

                S_SEND_ADDR: begin
                    ext_out_o <= addr_r;
                    state     <= S_DATA0;
                end

                S_DATA0: begin
                    ext_out_o <= wdata_r[7:0];
                    state     <= S_DATA1;
                end

                S_DATA1: begin
                    ext_out_o      <= wdata_r[15:8];
                    rdata_buf[7:0] <= ext_in_i;
                    state          <= S_DATA2;
                end

                S_DATA2: begin
                    ext_out_o       <= wdata_r[23:16];
                    rdata_buf[15:8] <= ext_in_i;
                    state           <= S_DATA3;
                end

                S_DATA3: begin
                    ext_out_o        <= wdata_r[31:24];
                    rdata_buf[23:16] <= ext_in_i;
                    state            <= S_LATCH;
                end

                S_LATCH: begin
                    ext_out_o <= 8'h0;
                    if (addr_match) begin
                        if (mem_sel_r) begin
                            // RAM 事务完成：锁存数据，触发强制取指
                            s1_rdata_o   <= {ext_in_i, rdata_buf};
                            need_fetch_r <= 1'b1;
                        end else begin
                            // ROM 事务完成：锁存指令，释放 stall
                            s0_rdata_o       <= {ext_in_i, rdata_buf};
                            transaction_done <= 1'b1;
                            need_fetch_r     <= 1'b0;
                        end
                    end
                    // addr_match=0（分支改变 PC）：丢弃，S_IDLE 以新 PC 重取
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule