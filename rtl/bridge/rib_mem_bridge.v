`include "../core/defines.v"

// SoC侧存储器桥接模块（7状态FSM，8周期/事务）
//
// 强制取指机制：三种情形均需在 CPU 推进前确保 s0_rdata_o 持有当前 PC 指令：
//   1. RAM 事务（need_fetch_r）：m0 访问 s1(RAM)，bridge 完成后立即做一次 ROM 取指
//   2. 非 bridge slave 访问（force_fetch_i）：m0 访问 PWM/UART 等无 bridge 的外设，
//      RIB 将 m0 授权，m1 无法取指。bridge 收到 force_fetch_i=1 后强制做 ROM 取指，
//      整个过程 stall 维持，CPU 不会推进直至取指完成。
//   3. 分支：addr_match 失败时自动重取（已有机制）。
//
// addr_match 使用 pc_i（冻结 PC，不依赖 RIB grant 状态）：
//   m0 占总线时 s0_addr_i=0，原用 s0_addr_i 会导致误判；pc_i 始终有效。
//
// 采样对齐（以读ROM[n]为例，T=0为S_IDLE pending拍）：
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

    // 当前 PC（Hold_Freeze 期间保持不变，用于强制取指）
    input  wire [31:0] pc_i,

    // m0 正在访问非 bridge slave（PWM/UART 等）时置 1，
    // 通知 bridge 强制取当前 PC 的指令（m1 此时被 m0 阻塞无法取指）
    input  wire        force_fetch_i,

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

    wire any_cs  = s0_cs_i || s1_cs_i;

    // 强制取指条件：need_fetch_r（RAM 后）或 force_fetch_i（非 bridge slave）
    wire force_rom = need_fetch_r || force_fetch_i;

    // pending：有正常 bridge 请求或需要强制取指，且当前空闲且非自由拍
    wire pending = (any_cs || force_rom) && (state == S_IDLE) && !transaction_done;

    assign stall_o = (state != S_IDLE) || pending || need_fetch_r;

    // addr_match：ROM 事务始终用 pc_i（冻结 PC），RAM 事务用 s1_addr_i
    wire [7:0] cur_word_addr = mem_sel_r ? s1_addr_i[9:2] : pc_i[9:2];
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
                S_IDLE: begin
                    if (!transaction_done) begin
                        if (force_rom) begin
                            // 强制 ROM 取指（RAM 事务后，或 m0 占总线阻塞 m1）
                            mem_sel_r <= 1'b0;
                            addr_r    <= pc_i[9:2];
                            we_r      <= 1'b0;
                            wdata_r   <= `ZeroWord;
                            ext_out_o <= {1'b1, 1'b0, 1'b0, 5'b0};
                            state     <= S_SEND_ADDR;
                        end else if (any_cs) begin
                            // 正常仲裁：s1(RAM) 优先于 s0(ROM)
                            mem_sel_r <= s1_cs_i;
                            addr_r    <= s1_cs_i ? s1_addr_i[9:2] : s0_addr_i[9:2];
                            we_r      <= s1_cs_i ? s1_we_i        : s0_we_i;
                            wdata_r   <= s1_cs_i ? s1_wdata_i     : s0_wdata_i;
                            ext_out_o <= {1'b1, s1_cs_i,
                                          (s1_cs_i ? s1_we_i : s0_we_i),
                                          5'b0};
                            state     <= S_SEND_ADDR;
                        end else begin
                            ext_out_o <= 8'h0;
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
                            // ROM 事务完成（普通取指或强制取指）：释放 stall
                            s0_rdata_o       <= {ext_in_i, rdata_buf};
                            transaction_done <= 1'b1;
                            need_fetch_r     <= 1'b0;
                        end
                    end
                    // addr_match=0：PC 已改变（分支），丢弃数据，S_IDLE 重取
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule