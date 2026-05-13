`include "../core/defines.v"

// SoC侧存储器桥接模块（7状态FSM，8周期/事务）
//
// 矛盾修复：
//   矛盾1（取指被数据访问中断）：RAM 事务完成后设 need_fetch_r，
//     在 S_IDLE 以 pc_i（冻结 PC）强制发起一次 ROM 取指，
//     ROM 取指完成后才置 transaction_done 释放 stall。
//     保证自由拍时 s0_rdata_o 持有当前 PC 的有效指令。
//
//   矛盾2（m0 悬空一拍重启）：transaction_done 已提供一个
//     自由拍供流水线推进，need_fetch_r 机制确保该拍内
//     s0_rdata_o 有效，不会触发重复 m0 事务。
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

    // 当前 PC（Hold_Freeze 期间保持不变，用于 RAM 事务后强制取指）
    input  wire [31:0] pc_i,

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
    wire pending = any_cs && (state == S_IDLE) && !transaction_done;

    // need_fetch_r 保持 stall 直到强制取指完成
    assign stall_o = (state != S_IDLE) || pending || need_fetch_r;

    // 地址比对：
    //   RAM 事务用 s1_addr_i（数据地址，RIB 始终有效）
    //   ROM 事务始终用 pc_i（冻结 PC，不依赖 RIB grant 状态）
    //     原因：m0 占总线（如访问 PWM）时 s0_addr_i=0，会造成 addr_match 误判
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
                        if (need_fetch_r) begin
                            // RAM 事务后强制 ROM 取指（使用冻结 PC）
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
                            // RAM 事务完成：锁存数据，触发强制取指，stall 继续
                            s1_rdata_o   <= {ext_in_i, rdata_buf};
                            need_fetch_r <= 1'b1;
                        end else begin
                            // ROM 事务完成（普通取指或强制取指）：释放 stall
                            s0_rdata_o       <= {ext_in_i, rdata_buf};
                            transaction_done <= 1'b1;
                            need_fetch_r     <= 1'b0;
                        end
                    end
                    // addr_match=0（分支改变 PC）：丢弃数据，不改 need_fetch_r，
                    // 下一拍 S_IDLE 重新 pending（普通取指或强制取指均适用）
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule