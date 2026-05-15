`include "../core/defines.v"

// I2C Master 外设（单字节读写，7位寻址，100kHz Standard Mode）
// 总线地址：0x7xxx_xxxx（Slave 7）
//
// 寄存器映射（addr[17:16]）：
//   2'b01  CTRL  0x7001_0000  [6:0]=从机地址 [7]=R/W [8]=START触发(写) [9]=BUSY(读)
//   2'b10  WDATA 0x7002_0000  [7:0]=写入从机的数据
//   2'b11  RDATA 0x7003_0000  [7:0]=从从机读到的数据（只读）
//
// SDA 驱动：sda_link=1时推挽（sda_out_r即线值），sda_link=0时高阻（从机驱动）
// io_scl：主设备独占输出
module i2c (
    input  wire        clk,
    input  wire        rst,

    // RIB Slave 7 总线接口
    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o,
    input  wire        we_i,

    // I2C 引脚
    output wire        io_scl,
    inout  wire        io_sda
);

    // 50MHz / 100kHz / 2 = 250 个系统时钟 / 半个 SCL 周期
    localparam CLK_DIV = 9'd250;

    // 内部寄存器
    reg [6:0] ctrl_addr;
    reg       ctrl_rw;
    reg       ctrl_busy;
    reg       ctrl_two_byte;  // 1=2字节读模式（RT 指令使用）
    reg       second_byte;    // 2字节读模式中：已在接收第2字节
    reg [7:0] wdata_r;
    reg [7:0] rdata_r;        // 读数据（单字节模式）/ 2字节模式的第2字节（LSB）
    reg [7:0] rdata_b1;       // 2字节读模式的第1字节（MSB），地址 0x7004_0000

    wire [1:0] reg_sel = addr_i[17:16];

    // 状态定义
    localparam ST_IDLE     = 4'd0;
    localparam ST_START    = 4'd1;   // START 条件（2 半周期）
    localparam ST_ADDR     = 4'd2;   // 发送地址+RW（8 bit × 2 半周期）
    localparam ST_ADDR_ACK = 4'd3;   // 地址 ACK（2 半周期）
    localparam ST_WDATA    = 4'd4;   // 发送写数据（8 bit × 2 半周期）
    localparam ST_WACK     = 4'd5;   // 写数据 ACK（2 半周期）
    localparam ST_RDATA    = 4'd6;   // 接收读数据（8 bit × 2 半周期）
    localparam ST_RACK     = 4'd9;   // 主机发 ACK（2字节读模式，字节间）
    localparam ST_RNACK    = 4'd7;   // 主机发 NACK（2 半周期）
    localparam ST_STOP     = 4'd8;   // STOP 条件（2 半周期）

    reg [3:0] state;
    reg [8:0] half_cnt;   // 半周期计数器（0 ~ CLK_DIV-1）
    reg [2:0] bit_cnt;    // bit 计数器（7 downto 0）
    reg       half;       // 0=SCL低半周期，1=SCL高半周期
    reg [7:0] shift_r;    // 移位寄存器（发送/接收）
    reg       scl_r;
    reg       sda_out_r;  // SDA 线值（sda_link=1时有效：1=高，0=低）
    reg       sda_link;   // 1=主机推挽驱动，0=高阻（从机 ACK/DATA）

    wire half_done = (half_cnt == CLK_DIV - 9'd1);
    wire sda_in    = io_sda;

    assign io_scl = scl_r;
    assign io_sda = sda_link ? sda_out_r : 1'bz;

    // 总线读回
    always @(*) begin
        data_o = 32'h0;
        case (reg_sel)
            2'b01: data_o = {21'h0, ctrl_two_byte, ctrl_busy, 1'b0, ctrl_rw, ctrl_addr};
            2'b10: data_o = {24'h0, wdata_r};
            2'b11: data_o = {16'h0, rdata_b1, rdata_r};
            default: data_o = 32'h0;
        endcase
    end

    // 半周期计数器
    always @(posedge clk) begin
        if (rst == `RstEnable || state == ST_IDLE)
            half_cnt <= 9'd0;
        else if (half_done)
            half_cnt <= 9'd0;
        else
            half_cnt <= half_cnt + 9'd1;
    end

    // 主状态机 + 寄存器写入
    always @(posedge clk) begin
        if (rst == `RstEnable) begin
            state        <= ST_IDLE;
            half         <= 1'b0;
            bit_cnt      <= 3'd7;
            shift_r      <= 8'h0;
            scl_r        <= 1'b1;
            sda_out_r    <= 1'b1;
            sda_link     <= 1'b1;
            ctrl_addr    <= 7'h0;
            ctrl_rw      <= 1'b0;
            ctrl_busy    <= 1'b0;
            ctrl_two_byte <= 1'b0;
            second_byte  <= 1'b0;
            wdata_r      <= 8'h0;
            rdata_r      <= 8'h0;
            rdata_b1     <= 8'h0;
        end else begin

            if (we_i && !ctrl_busy && reg_sel == 2'b10)
                wdata_r <= data_i[7:0];

            case (state)
                ST_IDLE: begin
                    scl_r <= 1'b1; sda_out_r <= 1'b1; sda_link <= 1'b1;
                    if (we_i && reg_sel == 2'b01 && data_i[8]) begin
                        ctrl_addr     <= data_i[6:0];
                        ctrl_rw       <= data_i[7];
                        ctrl_two_byte <= data_i[10];
                        second_byte   <= 1'b0;
`ifdef I2C_DEBUG_LOOPBACK
                        rdata_b1  <= 8'h19;
                        rdata_r   <= 8'h00;
                        ctrl_busy <= 1'b0;
`else
                        ctrl_busy     <= 1'b1;
                        sda_out_r     <= 1'b0;
                        half          <= 1'b0;
                        state         <= ST_START;
`endif
                    end
                end

                ST_START: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b0;
                        half  <= 1'b1;
                    end else begin
                        shift_r   <= {ctrl_addr, ctrl_rw};
                        sda_out_r <= ctrl_addr[6];
                        bit_cnt   <= 3'd7;
                        half      <= 1'b0;
                        state     <= ST_ADDR;
                    end
                end

                ST_ADDR: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        scl_r <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            sda_out_r <= 1'b1;
                            sda_link  <= 1'b0;
                            half      <= 1'b0;
                            state     <= ST_ADDR_ACK;
                        end else begin
                            shift_r   <= {shift_r[6:0], 1'b0};
                            sda_out_r <= shift_r[6];
                            bit_cnt   <= bit_cnt - 3'd1;
                            half      <= 1'b0;
                        end
                    end
                end

                ST_ADDR_ACK: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        scl_r <= 1'b0;
                        half  <= 1'b0;
                        if (!ctrl_rw) begin
                            shift_r   <= wdata_r;
                            sda_out_r <= wdata_r[7];
                            sda_link  <= 1'b1;
                            bit_cnt   <= 3'd7;
                            state     <= ST_WDATA;
                        end else begin
                            sda_out_r <= 1'b1;
                            bit_cnt   <= 3'd7;
                            state     <= ST_RDATA;
                        end
                    end
                end

                ST_WDATA: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        scl_r <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            sda_out_r <= 1'b1;
                            sda_link  <= 1'b0;
                            half      <= 1'b0;
                            state     <= ST_WACK;
                        end else begin
                            shift_r   <= {shift_r[6:0], 1'b0};
                            sda_out_r <= shift_r[6];
                            bit_cnt   <= bit_cnt - 3'd1;
                            half      <= 1'b0;
                        end
                    end
                end

                ST_WACK: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        scl_r     <= 1'b0;
                        sda_out_r <= 1'b0;
                        sda_link  <= 1'b1;
                        half      <= 1'b0;
                        state     <= ST_STOP;
                    end
                end

                ST_RDATA: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                        if (bit_cnt == 3'd0) begin
                            shift_r <= {shift_r[6:0], sda_in};
                        end else begin
                            shift_r <= {shift_r[6:0], sda_in};
                            bit_cnt <= bit_cnt - 3'd1;
                        end
                    end else begin
                        scl_r <= 1'b0;
                        half  <= 1'b0;
                        if (bit_cnt == 3'd0) begin
                            if (ctrl_two_byte && !second_byte) begin
                                rdata_b1    <= shift_r;
                                sda_out_r   <= 1'b0;
                                sda_link    <= 1'b1;
                                second_byte <= 1'b1;
                                bit_cnt     <= 3'd7;
                                state       <= ST_RACK;
                            end else begin
                                rdata_r   <= shift_r;
                                sda_out_r <= 1'b1;
                                sda_link  <= 1'b1;
                                state     <= ST_RNACK;
                            end
                        end
                    end
                end

                ST_RACK: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        scl_r     <= 1'b0;
                        sda_out_r <= 1'b1;
                        sda_link  <= 1'b0;
                        bit_cnt   <= 3'd7;
                        half      <= 1'b0;
                        state     <= ST_RDATA;
                    end
                end

                ST_RNACK: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        scl_r     <= 1'b0;
                        sda_out_r <= 1'b0;
                        half      <= 1'b0;
                        state     <= ST_STOP;
                    end
                end

                ST_STOP: if (half_done) begin
                    if (!half) begin
                        scl_r <= 1'b1;
                        half  <= 1'b1;
                    end else begin
                        sda_out_r <= 1'b1;
                        ctrl_busy <= 1'b0;
                        half      <= 1'b0;
                        state     <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
