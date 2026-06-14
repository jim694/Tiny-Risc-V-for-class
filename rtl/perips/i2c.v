`include "../core/defines.v"

// I2C Master（参照 ref_temp_test/i2c_read_lm75.v 重写）
// 核心改动：4 相自由运行时钟，SDA 在 SCL_LOW 稳定后改变，在 SCL_HIG 稳定后采样
// 与原版（半周期计数）的区别：SDA 变化与 SCL 边沿之间有 50 cycle 建立裕量
//
// 寄存器映射（addr[17:16]）：
//   2'b01  CTRL  0x7001_0000  [6:0]=从机地址 [7]=R/W [8]=START触发(写) [9]=BUSY(读) [10]=TWO_BYTE [11]=ACK_ERROR
//   2'b10  WDATA 0x7002_0000  [7:0]=写数据
//   2'b11  RDATA 0x7003_0000  [15:8]=第1字节MSB [7:0]=第2字节LSB
//
// SCL：推挽输出（同参考设计）
// SDA：sda_link=1 推挽，sda_link=0 高阻（从机 ACK/DATA 期间）

module i2c (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o,
    input  wire        we_i,

    output wire        io_scl,
    inout  wire        io_sda
);

    // 4 相时钟：50MHz / 250kHz / 4 = 50 cycles/相
    // SCL_POS @ cnt_delay=0  : SCL 上升（建立高）
    // SCL_HIG @ cnt_delay=50 : SCL 稳定高（采样 SDA）
    // SCL_NEG @ cnt_delay=100: SCL 下降（建立低）
    // SCL_LOW @ cnt_delay=150: SCL 稳定低（改变 SDA）
    localparam PHASE = 9'd50;

    reg [8:0] cnt_delay;
    reg       scl_r;
    reg       sda_out_r;
    reg       sda_link;

    wire SCL_POS = (cnt_delay == 9'd0);
    wire SCL_HIG = (cnt_delay == PHASE);
    wire SCL_NEG = (cnt_delay == PHASE * 2);
    wire SCL_LOW = (cnt_delay == PHASE * 3);
    wire sda_in  = io_sda;

    assign io_scl = scl_r;
    assign io_sda = sda_link ? sda_out_r : 1'bz;

    // 控制/数据寄存器
    reg [6:0] ctrl_addr;
    reg       ctrl_rw;
    reg       ctrl_busy;
    reg       ctrl_two_byte;
    reg       ctrl_ack_error;
    reg [7:0] wdata_r;
    reg [7:0] rdata_b1;   // 第 1 字节（MSB，LM75 温度高字节）
    reg [7:0] rdata_r;    // 第 2 字节（LSB，LM75 温度低字节）
    reg [7:0] db_r;       // 地址帧寄存器 = {ctrl_addr[6:0], ctrl_rw}
    reg [3:0] num;        // bit 计数器（同参考设计）

    wire [1:0] reg_sel = addr_i[17:16];

    // 状态定义（同参考设计命名）
    localparam ST_IDLE      = 4'd0;
    localparam ST_START     = 4'd1;
    localparam ST_ADDR      = 4'd2;
    localparam ST_ADDR_ACK  = 4'd3;   // 参考设计 ACK1
    localparam ST_WDATA     = 4'd4;
    localparam ST_WACK      = 4'd5;
    localparam ST_RDATA1    = 4'd6;   // 参考设计 DATA1
    localparam ST_RACK      = 4'd7;   // 参考设计 ACK2
    localparam ST_RDATA2    = 4'd8;   // 参考设计 DATA2
    localparam ST_RNACK     = 4'd9;   // 参考设计 NACK
    localparam ST_STOP      = 4'd10;  // 参考设计 STOP
    localparam ST_PRE_STOP  = 4'd11;  // NACK/ACK错误后，SDA先拉低再产生STOP

    reg [3:0] state;

    wire i2c_active = (state != ST_IDLE);

    // 4 相计数器：事务期间运行，空闲时保持 SCL/SDA 为高
    always @(posedge clk) begin
        if (rst == `RstEnable || !i2c_active || cnt_delay == PHASE * 4 - 9'd1)
            cnt_delay <= 9'd0;
        else
            cnt_delay <= cnt_delay + 9'd1;
    end

    // SCL 生成：SCL_POS 拉高，SCL_NEG 拉低
    always @(posedge clk) begin
        if (rst == `RstEnable || !i2c_active)
            scl_r <= 1'b1;
        else if (SCL_POS)
            scl_r <= 1'b1;
        else if (SCL_NEG)
            scl_r <= 1'b0;
    end

    // 总线读回
    always @(*) begin
        data_o = 32'h0;
        case (reg_sel)
            2'b01: data_o = {20'h0, ctrl_ack_error, ctrl_two_byte, ctrl_busy, 1'b0, ctrl_rw, ctrl_addr};
            2'b10: data_o = {24'h0, wdata_r};
            2'b11: data_o = {16'h0, rdata_b1, rdata_r};
            default: data_o = 32'h0;
        endcase
    end

    // 主状态机（结构参照 i2c_read_lm75.v）
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            state         <= ST_IDLE;
            num           <= 4'd0;
            db_r          <= 8'h0;
            ctrl_addr     <= 7'h0;
            ctrl_rw       <= 1'b0;
            ctrl_busy     <= 1'b0;
            ctrl_two_byte <= 1'b0;
            ctrl_ack_error <= 1'b0;
            wdata_r       <= 8'h0;
            rdata_b1      <= 8'h0;
            rdata_r       <= 8'h0;
            sda_out_r     <= 1'b1;
            sda_link      <= 1'b1;
        end else begin

            if (we_i && !ctrl_busy && reg_sel == 2'b10)
                wdata_r <= data_i[7:0];

            case (state)

                // ── IDLE ──────────────────────────────────────────────────────
                ST_IDLE: begin
                    sda_link  <= 1'b1;
                    sda_out_r <= 1'b1;
                    if (we_i && reg_sel == 2'b01 && data_i[8]) begin
                        ctrl_addr     <= data_i[6:0];
                        ctrl_rw       <= data_i[7];
                        ctrl_two_byte <= data_i[10];
                        ctrl_ack_error <= 1'b0;
                        ctrl_busy     <= 1'b1;
                        db_r          <= {data_i[6:0], data_i[7]};
`ifdef I2C_DEBUG_LOOPBACK
                        rdata_b1  <= 8'h19;
                        rdata_r   <= 8'h00;
                        ctrl_busy <= 1'b0;
`else
                        state     <= ST_START;
`endif
                    end
                end

                // ── START（参照参考设计：在 SCL_HIG 令 SDA 下降 = START 条件）──
                ST_START: begin
                    if (SCL_HIG) begin
                        sda_out_r <= 1'b0;   // SDA 下降，SCL=1 → START
                        num       <= 4'd0;
                        state     <= ST_ADDR;
                    end
                end

                // ── ADDR（参照参考设计 ADDR：在 SCL_LOW 逐位设置 SDA）─────────
                // num=0..7 发送 db_r[7..0]，num=8 释放 SDA 等待 ACK
                ST_ADDR: begin
                    if (SCL_LOW) begin
                        if (num == 4'd8) begin
                            num       <= 4'd0;
                            sda_out_r <= 1'b1;
                            sda_link  <= 1'b0;   // 高阻，从机 ACK
                            state     <= ST_ADDR_ACK;
                        end else begin
                            case (num)
                                4'd0: sda_out_r <= db_r[7];
                                4'd1: sda_out_r <= db_r[6];
                                4'd2: sda_out_r <= db_r[5];
                                4'd3: sda_out_r <= db_r[4];
                                4'd4: sda_out_r <= db_r[3];
                                4'd5: sda_out_r <= db_r[2];
                                4'd6: sda_out_r <= db_r[1];
                                4'd7: sda_out_r <= db_r[0];
                                default: ;
                            endcase
                            num <= num + 4'd1;
                        end
                    end
                end

                // ── ADDR ACK：SCL_HIG 采样 ACK，NACK 则终止事务 ──────────────
                ST_ADDR_ACK: begin
                    if (SCL_HIG) begin
                        if (sda_in) begin
                            ctrl_ack_error <= 1'b1;
                            state          <= ST_PRE_STOP;
                        end
                    end else if (SCL_NEG) begin
                        num <= 4'd0;
                        if (!ctrl_rw) begin
                            // 写事务：主机接管 SDA，发送 WDATA
                            sda_link  <= 1'b1;
                            sda_out_r <= wdata_r[7];
                            state     <= ST_WDATA;
                        end else begin
                            // 读事务：sda_link 保持 0，从机驱动
                            state <= ST_RDATA1;
                        end
                    end
                end

                // ── WDATA（SCL_LOW 逐位设置 SDA）─────────────────────────────
                ST_WDATA: begin
                    if (SCL_LOW) begin
                        if (num == 4'd8) begin
                            num      <= 4'd0;
                            sda_link <= 1'b0;
                            state    <= ST_WACK;
                        end else begin
                            case (num)
                                4'd0: sda_out_r <= wdata_r[7];
                                4'd1: sda_out_r <= wdata_r[6];
                                4'd2: sda_out_r <= wdata_r[5];
                                4'd3: sda_out_r <= wdata_r[4];
                                4'd4: sda_out_r <= wdata_r[3];
                                4'd5: sda_out_r <= wdata_r[2];
                                4'd6: sda_out_r <= wdata_r[1];
                                4'd7: sda_out_r <= wdata_r[0];
                                default: ;
                            endcase
                            num <= num + 4'd1;
                        end
                    end
                end

                // ── WACK：SCL_HIG 采样 ACK，NACK 则记录错误 ──────────────────
                ST_WACK: begin
                    if (SCL_HIG) begin
                        if (sda_in) begin
                            ctrl_ack_error <= 1'b1;
                        end
                    end else if (SCL_NEG) begin
                        sda_link  <= 1'b1;
                        sda_out_r <= 1'b0;   // 准备 STOP：SDA=0
                        state     <= ST_STOP;
                    end
                end

                // ── RDATA1（参照参考设计 DATA1：SCL_HIG 采样，SCL_NEG num==8 → ACK2）
                ST_RDATA1: begin
                    if (SCL_HIG) begin
                        case (num)
                            4'd0: rdata_b1[7] <= sda_in;
                            4'd1: rdata_b1[6] <= sda_in;
                            4'd2: rdata_b1[5] <= sda_in;
                            4'd3: rdata_b1[4] <= sda_in;
                            4'd4: rdata_b1[3] <= sda_in;
                            4'd5: rdata_b1[2] <= sda_in;
                            4'd6: rdata_b1[1] <= sda_in;
                            4'd7: rdata_b1[0] <= sda_in;
                            default: ;
                        endcase
                        num <= num + 4'd1;
                    end else if (SCL_NEG && num == 4'd8) begin
                        num       <= 4'd0;
                        sda_link  <= 1'b1;
                        sda_out_r <= 1'b1;   // 主机接管，准备发 ACK
                        state     <= ST_RACK;
                    end
                end

                // ── RACK（参照参考设计 ACK2：SCL_LOW 驱动 ACK，SCL_NEG → DATA2）
                ST_RACK: begin
                    if (SCL_LOW) begin
                        sda_out_r <= 1'b0;   // ACK（SDA=0 在 SCL 低期建立）
                    end else if (SCL_NEG) begin
                        sda_link  <= 1'b0;   // 高阻，从机驱动第 2 字节
                        num       <= 4'd0;
                        state     <= ST_RDATA2;
                    end
                end

                // ── RDATA2（参照参考设计 DATA2：SCL_HIG 采样，SCL_LOW num==8 → NACK）
                ST_RDATA2: begin
                    if (SCL_HIG) begin
                        case (num)
                            4'd0: rdata_r[7] <= sda_in;
                            4'd1: rdata_r[6] <= sda_in;
                            4'd2: rdata_r[5] <= sda_in;
                            4'd3: rdata_r[4] <= sda_in;
                            4'd4: rdata_r[3] <= sda_in;
                            4'd5: rdata_r[2] <= sda_in;
                            4'd6: rdata_r[1] <= sda_in;
                            4'd7: rdata_r[0] <= sda_in;
                            default: ;
                        endcase
                        num <= num + 4'd1;
                    end else if (SCL_LOW && num == 4'd8) begin
                        num       <= 4'd0;
                        sda_link  <= 1'b1;
                        sda_out_r <= 1'b1;   // NACK（SDA=1）
                        state     <= ST_RNACK;
                    end
                end

                // ── RNACK：标准读结束 NACK，第 9 个 SCL 周期保持 SDA=1 ──────
                ST_RNACK: begin
                    if (SCL_LOW) begin
                        sda_link  <= 1'b1;
                        sda_out_r <= 1'b1;   // NACK
                    end else if (SCL_NEG) begin
                        state <= ST_PRE_STOP;
                    end
                end

                // ── PRE_STOP：SCL 低期拉低 SDA，为 STOP 的上升沿做准备 ─────
                ST_PRE_STOP: begin
                    if (SCL_LOW) begin
                        sda_link  <= 1'b1;
                        sda_out_r <= 1'b0;
                        state     <= ST_STOP;
                    end
                end

                // ── STOP（参照参考设计 STOP：SCL_HIG 令 SDA=1 = STOP 条件）────
                ST_STOP: begin
                    if (SCL_HIG) begin
                        sda_out_r <= 1'b1;   // SDA 上升（SCL=1）→ STOP
                        ctrl_busy <= 1'b0;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
