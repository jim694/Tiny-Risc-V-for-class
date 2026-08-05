 /*
 Copyright 2020 Blue Liang, liangkangnan@163.com

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

`include "../core/defines.v"

// tinyriscv soc顶层模块
// ROM/RAM 位于 SoC 外部；SoC 侧仅保留 rib_mem_bridge 和 8-bit 外部存储接口
module tinyriscv_soc_top(

    input wire clk,
    input wire rst,

    output reg over,
    output reg succ,

    input wire uart_debug_pin,
    output wire uart_tx_pin,
    input wire uart_rx_pin,

    output wire [3:0] pwm_o,
    output wire io_scl,
    inout wire io_sda,

    output wire [7:0] ext_mem_out,
    input wire [7:0] ext_mem_in,
    input wire [2:0] chip_sel,
    output wire [3:0] selected_o
    );


    // master 0 interface
    wire[`MemAddrBus] m0_addr_i;
    wire[`MemBus] m0_data_i;
    wire[`MemBus] m0_data_o;
    wire m0_req_i;
    wire m0_we_i;

    // master 1 interface
    wire[`MemAddrBus] m1_addr_i;
    wire[`MemBus] m1_data_i;
    wire[`MemBus] m1_data_o;
    wire m1_req_i;
    wire m1_we_i;

    // master 2 interface
    wire[`MemAddrBus] m2_addr_i;
    wire[`MemBus] m2_data_i;
    wire[`MemBus] m2_data_o;
    wire m2_req_i;
    wire m2_we_i;

    // master 3 interface
    wire[`MemAddrBus] m3_addr_i;
    wire[`MemBus] m3_data_i;
    wire[`MemBus] m3_data_o;
    wire m3_req_i;
    wire m3_we_i;

    // slave 0 interface（ROM）
    wire[`MemAddrBus] s0_addr_o;
    wire[`MemBus] s0_data_o;
    wire[`MemBus] s0_data_i;
    wire s0_we_o;
    wire s0_cs_o;

    // slave 1 interface（RAM）
    wire[`MemAddrBus] s1_addr_o;
    wire[`MemBus] s1_data_o;
    wire[`MemBus] s1_data_i;
    wire s1_we_o;
    wire s1_cs_o;

    // slave 3 interface: UART
    wire[`MemAddrBus] s3_addr_o;
    wire[`MemBus] s3_data_o;
    wire[`MemBus] s3_data_i;
    wire s3_we_o;

    // slave 6 interface: PWM
    wire[`MemAddrBus] s6_addr_o;
    wire[`MemBus] s6_data_o;
    wire[`MemBus] s6_data_i;
    wire s6_we_o;

    // slave 7 interface: I2C
    wire[`MemAddrBus] s7_addr_o;
    wire[`MemBus] s7_data_o;
    wire[`MemBus] s7_data_i;
    wire s7_we_o;

    // rib
    wire rib_hold_flag_o;


    // tinyriscv

    // 存储器桥接暂停信号
    wire mem_bridge_stall;

    // UART 下载模式下仅保持 CPU 核复位，外设和下载状态机仍使用板级复位
    wire cpu_rst = rst & ~uart_debug_pin;

    // CPU hold：桥接事务期间冻结整条流水线
    wire cpu_hold = mem_bridge_stall;





    wire[`RegBus] test_x3;
    wire[`RegBus] test_x26;
    wire[`RegBus] test_x27;

    assign m2_addr_i = `ZeroWord;
    assign m2_data_i = `ZeroWord;
    assign m2_req_i = `RIB_NREQ;
    assign m2_we_i = `WriteDisable;
always @ (posedge clk) begin
        if (cpu_rst == `RstEnable) begin
            over <= 1'b1;
            succ <= 1'b1;
        end else begin
            over <= ~test_x26;
            succ <= ~test_x27;
        end
    end

    // tinyriscv处理器核模块例化
    tinyriscv_cluster u_tinyriscv(
        .clk(clk),
        .rst(cpu_rst),
        .chip_sel_i(chip_sel),
        .rib_ex_data_i(m0_data_o),
        .rib_pc_data_i(m1_data_o),
        .rib_hold_flag_i(cpu_hold),
        .rib_ex_addr_o(m0_addr_i),
        .rib_ex_data_o(m0_data_i),
        .rib_ex_req_o(m0_req_i),
        .rib_ex_we_o(m0_we_i),
        .rib_pc_addr_o(m1_addr_i),
        .selected_o(selected_o),
        .test_x26_o(test_x26),
        .test_x27_o(test_x27)
    );

    // SoC侧存储器桥接模块例化
    rib_mem_bridge u_rib_mem_bridge(
        .clk(clk),
        .rst(rst),
        .s0_addr_i(s0_addr_o),
        .s0_wdata_i(s0_data_o),
        .s0_rdata_o(s0_data_i),
        .s0_we_i(s0_we_o),
        .s0_cs_i(s0_cs_o),
        .s1_addr_i(s1_addr_o),
        .s1_wdata_i(s1_data_o),
        .s1_rdata_o(s1_data_i),
        .s1_we_i(s1_we_o),
        .s1_cs_i(s1_cs_o),
        .ext_out_o(ext_mem_out),
        .ext_in_i(ext_mem_in),
        .stall_o(mem_bridge_stall)
    );

    // PWM模块例化
    pwm u_pwm(
        .clk(clk),
        .rst(rst),
        .addr_i(s6_addr_o),
        .data_i(s6_data_o),
        .data_o(s6_data_i),
        .we_i(s6_we_o),
        .pwm_o(pwm_o)
    );

    // I2C模块例化
    i2c u_i2c(
        .clk(clk),
        .rst(rst),
        .addr_i(s7_addr_o),
        .data_i(s7_data_o),
        .data_o(s7_data_i),
        .we_i(s7_we_o),
        .io_scl(io_scl),
        .io_sda(io_sda)
    );

    // uart模块例化
    uart uart_0(
        .clk(clk),
        .rst(rst),
        .we_i(s3_we_o),
        .addr_i(s3_addr_o),
        .data_i(s3_data_o),
        .data_o(s3_data_i),
        .tx_pin(uart_tx_pin),
        .rx_pin(uart_rx_pin)
    );

    // rib模块例化
    rib u_rib(
        .clk(clk),
        .rst(rst),

        .m0_addr_i(m0_addr_i),
        .m0_data_i(m0_data_i),
        .m0_data_o(m0_data_o),
        .m0_req_i(m0_req_i),
        .m0_we_i(m0_we_i),

        .m1_addr_i(m1_addr_i),
        .m1_data_i(`ZeroWord),
        .m1_data_o(m1_data_o),
        .m1_req_i(`RIB_REQ),
        .m1_we_i(`WriteDisable),

        .m2_addr_i(m2_addr_i),
        .m2_data_i(m2_data_i),
        .m2_data_o(m2_data_o),
        .m2_req_i(m2_req_i),
        .m2_we_i(m2_we_i),

        .m3_addr_i(m3_addr_i),
        .m3_data_i(m3_data_i),
        .m3_data_o(m3_data_o),
        .m3_req_i(m3_req_i),
        .m3_we_i(m3_we_i),

        .s0_addr_o(s0_addr_o),
        .s0_data_o(s0_data_o),
        .s0_data_i(s0_data_i),
        .s0_we_o(s0_we_o),
        .s0_cs_o(s0_cs_o),

        .s1_addr_o(s1_addr_o),
        .s1_data_o(s1_data_o),
        .s1_data_i(s1_data_i),
        .s1_we_o(s1_we_o),
        .s1_cs_o(s1_cs_o),

        .s3_addr_o(s3_addr_o),
        .s3_data_o(s3_data_o),
        .s3_data_i(s3_data_i),
        .s3_we_o(s3_we_o),

        .s6_addr_o(s6_addr_o),
        .s6_data_o(s6_data_o),
        .s6_data_i(s6_data_i),
        .s6_we_o(s6_we_o),

        .s7_addr_o(s7_addr_o),
        .s7_data_o(s7_data_o),
        .s7_data_i(s7_data_i),
        .s7_we_o(s7_we_o),

        .hold_flag_o(rib_hold_flag_o)
    );

    // 串口下载模块例化
    uart_debug u_uart_debug(
        .clk(clk),
        .rst(rst),
        .debug_en_i(uart_debug_pin),
        .stall_i(mem_bridge_stall),
        .req_o(m3_req_i),
        .mem_we_o(m3_we_i),
        .mem_addr_o(m3_addr_i),
        .mem_wdata_o(m3_data_i),
        .mem_rdata_i(m3_data_o)
    );


endmodule
