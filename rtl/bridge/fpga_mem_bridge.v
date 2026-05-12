`include "../core/defines.v"

// FPGA侧存储器桥接模块（6状态FSM）
// 内含 ROM（256×32-bit = 1KB）和 RAM（16×32-bit = 64B）
// CTRL[6]=mem_sel 区分访问目标：0=ROM，1=RAM
//
// 帧接收时序：
//   S_IDLE      ext_in[7]=1 → 识别 CTRL，解析 mem_sel, we
//   S_RECV_ADDR ext_in = ADDR；直接用 ext_in 组合读（addr_r 下一拍才更新）；输出 rdata[7:0]
//   S_DATA0     输出 rdata[15:8]；捕获 wdata[7:0]
//   S_DATA1     输出 rdata[23:16]；捕获 wdata[15:8]
//   S_DATA2     输出 rdata[31:24]；捕获 wdata[23:16]
//   S_DATA3     输出 0；捕获 wdata[31:24]；若写操作则同步写入存储体；→ S_IDLE
module fpga_mem_bridge (
    input  wire       clk,
    input  wire       rst,
    input  wire [7:0] ext_in_i,     // 来自 SoC 桥接
    output reg  [7:0] ext_out_o     // 向 SoC 桥接
);

    reg [31:0] _rom [0:255];    // ROM：256×32-bit = 1KB
    reg [31:0] _ram [0:15];     // RAM： 16×32-bit = 64B

    localparam S_IDLE      = 3'd0;
    localparam S_RECV_ADDR = 3'd1;
    localparam S_DATA0     = 3'd2;
    localparam S_DATA1     = 3'd3;
    localparam S_DATA2     = 3'd4;
    localparam S_DATA3     = 3'd5;

    reg [2:0]  state;
    reg        mem_sel_r;   // 0=ROM, 1=RAM
    reg        we_r;
    reg [7:0]  addr_r;      // 字地址（addr_r[7:0] for ROM, addr_r[3:0] for RAM）
    reg [31:0] rdata_r;     // 锁存读数据（S_RECV_ADDR 时锁存）
    reg [23:0] wdata_buf;   // 暂存写数据前三字节

    // 关键：S_RECV_ADDR 时 addr_r 还未更新，必须用 ext_in_i 直接组合读
    wire [31:0] rdata_from_ext = mem_sel_r ? _ram[ext_in_i[3:0]] : _rom[ext_in_i[7:0]];

    always @ (posedge clk) begin
        if (rst == `RstEnable) begin
            state     <= S_IDLE;
            ext_out_o <= 8'h0;
            mem_sel_r <= 1'b0;
            we_r      <= 1'b0;
            addr_r    <= 8'h0;
            rdata_r   <= `ZeroWord;
            wdata_buf <= 24'h0;
        end else begin
            case (state)
                // 等待帧起始：CTRL[7]=1
                S_IDLE: begin
                    ext_out_o <= 8'h0;
                    if (ext_in_i[7]) begin
                        mem_sel_r <= ext_in_i[6];
                        we_r      <= ext_in_i[5];
                        state     <= S_RECV_ADDR;
                    end
                end

                // 接收地址；用 ext_in_i 组合读（避免 addr_r 一拍延迟）；输出 rdata[7:0]
                S_RECV_ADDR: begin
                    addr_r    <= ext_in_i;
                    rdata_r   <= rdata_from_ext;
                    ext_out_o <= rdata_from_ext[7:0];
                    state     <= S_DATA0;
                end

                S_DATA0: begin
                    ext_out_o     <= rdata_r[15:8];
                    wdata_buf[7:0]<= ext_in_i;
                    state         <= S_DATA1;
                end

                S_DATA1: begin
                    ext_out_o      <= rdata_r[23:16];
                    wdata_buf[15:8]<= ext_in_i;
                    state          <= S_DATA2;
                end

                S_DATA2: begin
                    ext_out_o       <= rdata_r[31:24];
                    wdata_buf[23:16]<= ext_in_i;
                    state           <= S_DATA3;
                end

                // 写操作：{ext_in_i, wdata_buf} = {wdata[31:24], wdata[23:0]}
                S_DATA3: begin
                    ext_out_o <= 8'h0;
                    if (we_r) begin
                        if (mem_sel_r)
                            _ram[addr_r[3:0]] <= {ext_in_i, wdata_buf};
                        else
                            _rom[addr_r[7:0]] <= {ext_in_i, wdata_buf};
                    end
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;
            endcase
        end
    end

endmodule
