`include "../core/defines.v"

// 4通道PWM外设
// 总线地址：0x6xxx_xxxx（Slave 6）
//
// 寄存器映射（addr[27:0]关键位）：
//   addr[20]=0, addr[18]=0, addr[17:16]=ch → A[ch]（总周期，uint32）
//   addr[20]=0, addr[18]=1                 → C（4bit使能寄存器）
//   addr[20]=1, addr[17:16]=ch             → B[ch]（高电平时长，uint32）
//
// 写入A[i]或B[i]时，通道i的计数器立即复位（方案一）
module pwm (
    input  wire        clk,
    input  wire        rst,

    // RIB Slave 6 总线接口
    input  wire [31:0] addr_i,
    input  wire [31:0] data_i,
    output reg  [31:0] data_o,
    input  wire        we_i,

    // PWM 输出引脚
    output wire [3:0]  pwm_o
);

    // 内部寄存器
    reg [31:0] A [3:0];   // 总周期（0 = 停止）
    reg [31:0] B [3:0];   // 高电平时长
    reg [3:0]  C;          // 通道使能

    // 计数器
    reg [31:0] cnt [3:0];

    // 地址解码（组合）
    wire        sel_b = addr_i[20];
    wire        sel_c = ~addr_i[20] & addr_i[18];
    wire [1:0]  ch    = addr_i[17:16];

    // 写使能信号
    wire we_A = we_i & ~sel_b & ~sel_c;
    wire we_B = we_i &  sel_b;
    wire we_C = we_i &  sel_c;

    wire write_A0 = we_A & (ch == 2'd0);
    wire write_A1 = we_A & (ch == 2'd1);
    wire write_A2 = we_A & (ch == 2'd2);
    wire write_A3 = we_A & (ch == 2'd3);
    wire write_B0 = we_B & (ch == 2'd0);
    wire write_B1 = we_B & (ch == 2'd1);
    wire write_B2 = we_B & (ch == 2'd2);
    wire write_B3 = we_B & (ch == 2'd3);

    // 寄存器写入 + 计数器更新
    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            A[0] <= 32'h0; A[1] <= 32'h0; A[2] <= 32'h0; A[3] <= 32'h0;
            B[0] <= 32'h0; B[1] <= 32'h0; B[2] <= 32'h0; B[3] <= 32'h0;
            C    <= 4'h0;
            cnt[0] <= 32'h0; cnt[1] <= 32'h0;
            cnt[2] <= 32'h0; cnt[3] <= 32'h0;
        end else begin
            // 寄存器写入
            if (write_A0) A[0] <= data_i[31:0];
            if (write_A1) A[1] <= data_i[31:0];
            if (write_A2) A[2] <= data_i[31:0];
            if (write_A3) A[3] <= data_i[31:0];
            if (write_B0) B[0] <= data_i[31:0];
            if (write_B1) B[1] <= data_i[31:0];
            if (write_B2) B[2] <= data_i[31:0];
            if (write_B3) B[3] <= data_i[31:0];
            if (we_C)     C    <= data_i[3:0];

            // 通道 0 计数器
            if (write_A0 | write_B0)
                cnt[0] <= 32'h0;
            else if (A[0] != 32'h0 && cnt[0] >= A[0] - 32'h1)
                cnt[0] <= 32'h0;
            else if (A[0] != 32'h0)
                cnt[0] <= cnt[0] + 32'h1;

            // 通道 1 计数器
            if (write_A1 | write_B1)
                cnt[1] <= 32'h0;
            else if (A[1] != 32'h0 && cnt[1] >= A[1] - 32'h1)
                cnt[1] <= 32'h0;
            else if (A[1] != 32'h0)
                cnt[1] <= cnt[1] + 32'h1;

            // 通道 2 计数器
            if (write_A2 | write_B2)
                cnt[2] <= 32'h0;
            else if (A[2] != 32'h0 && cnt[2] >= A[2] - 32'h1)
                cnt[2] <= 32'h0;
            else if (A[2] != 32'h0)
                cnt[2] <= cnt[2] + 32'h1;

            // 通道 3 计数器
            if (write_A3 | write_B3)
                cnt[3] <= 32'h0;
            else if (A[3] != 32'h0 && cnt[3] >= A[3] - 32'h1)
                cnt[3] <= 32'h0;
            else if (A[3] != 32'h0)
                cnt[3] <= cnt[3] + 32'h1;
        end
    end

    // PWM 输出（组合逻辑）
    assign pwm_o[0] = C[0] & (A[0] != 32'h0) & (cnt[0] < B[0]);
    assign pwm_o[1] = C[1] & (A[1] != 32'h0) & (cnt[1] < B[1]);
    assign pwm_o[2] = C[2] & (A[2] != 32'h0) & (cnt[2] < B[2]);
    assign pwm_o[3] = C[3] & (A[3] != 32'h0) & (cnt[3] < B[3]);

    // 总线读回（组合逻辑）
    always @ (*) begin
        data_o = 32'h0;
        if (sel_b)
            data_o = B[ch];
        else if (sel_c)
            data_o = {28'h0, C};
        else
            data_o = A[ch];
    end

endmodule