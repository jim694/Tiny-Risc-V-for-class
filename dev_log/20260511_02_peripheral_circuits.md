# TinyRISCV 外设模块学习笔记

**日期：** 2026-05-11
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 1. 系统总体结构

TinyRISCV SoC 由以下部分组成：

```
                          RIB 总线（4主6从）
                         /      |      |      \
                       M0      M1      M2      M3
                   (CPU访存) (CPU取指) (JTAG) (串口下载)
                         \      |      |      /
                          ──────────────────
                      S0    S1    S2    S3    S4    S5
                     ROM   RAM  Timer  UART  GPIO  SPI
```

涉及文件：

| 文件 | 模块名 | 说明 |
|------|--------|------|
| `rtl/soc/tinyriscv_soc_top.v` | `tinyriscv_soc_top` | SoC 顶层，连接所有模块 |
| `rtl/core/rib.v` | `rib` | RIB 总线，负责地址路由与仲裁 |
| `rtl/perips/rom.v` | `rom` | 指令 ROM（4KB） |
| `rtl/perips/ram.v` | `ram` | 数据 RAM（4KB） |
| `rtl/perips/timer.v` | `timer` | 定时器/计数器，带中断 |
| `rtl/perips/uart.v` | `uart` | 串口通信 |
| `rtl/perips/gpio.v` | `gpio` | 双向 GPIO（2路） |
| `rtl/perips/spi.v` | `spi` | SPI 主机 |

---

## 2. RIB 总线

### 2.1 地址路由规则

RIB 根据访问地址的高 4 位（`addr[31:28]`）选择从设备：

| `addr[31:28]` | 从设备编号 | 挂载外设 | 地址范围 |
|--------------|-----------|---------|---------|
| `4'h0` | Slave 0 | ROM | `0x0000_0000` ~ `0x0FFF_FFFF` |
| `4'h1` | Slave 1 | RAM | `0x1000_0000` ~ `0x1FFF_FFFF` |
| `4'h2` | Slave 2 | Timer | `0x2000_0000` ~ `0x2FFF_FFFF` |
| `4'h3` | Slave 3 | UART | `0x3000_0000` ~ `0x3FFF_FFFF` |
| `4'h4` | Slave 4 | GPIO | `0x4000_0000` ~ `0x4FFF_FFFF` |
| `4'h5` | Slave 5 | SPI | `0x5000_0000` ~ `0x5FFF_FFFF` |

### 2.2 主设备仲裁优先级

固定优先级（高 → 低）：

```
Master 3（uart_debug 串口下载）> Master 0（CPU 执行级访存）> Master 2（JTAG）> Master 1（CPU 取指）
```

当 Master 3 有请求时，流水线暂停（`hold_flag_o = 1`）。Master 1（取指）不主动发请求，总是在无竞争时工作。

### 2.3 Master/Slave 接口信号

每个 Master 接口：

| 信号 | 方向（相对总线） | 说明 |
|------|----------------|------|
| `mN_addr_i` | input | 读写地址 |
| `mN_data_i` | input | 写数据 |
| `mN_data_o` | output | 读数据 |
| `mN_req_i` | input | 访问请求 |
| `mN_we_i` | input | 写使能 |

每个 Slave 接口（无 req 信号）：

| 信号 | 方向（相对总线） | 说明 |
|------|----------------|------|
| `sN_addr_o` | output | 读写地址 |
| `sN_data_o` | output | 写数据 |
| `sN_data_i` | input | 读数据 |
| `sN_we_o` | output | 写使能 |

---

## 3. 各外设模块端口

### 3.1 ROM（`rtl/perips/rom.v`）

只读指令存储器，深度 4096 字（16KB），但实际仿真中由 `$readmemh` 加载程序。

```verilog
module rom(
    input wire clk,
    input wire rst,
    input wire we_i,               // 写使能（ROM 中始终为 0）
    input wire[31:0] addr_i,       // 字节地址
    input wire[31:0] data_i,       // 写数据（ROM 不使用）
    output reg[31:0] data_o        // 读出指令
);
```

> **注意：** ROM 模块带有写接口（`we_i` / `data_i`），是为了接口对齐 RIB 总线统一的从设备格式，实际上写操作被内部逻辑忽略。

### 3.2 RAM（`rtl/perips/ram.v`）

可读写数据存储器，深度 4096 字（16KB）。接口与 ROM 完全相同，支持写操作。

```verilog
module ram(
    input wire clk,
    input wire rst,
    input wire we_i,               // 写使能
    input wire[31:0] addr_i,       // 字节地址
    input wire[31:0] data_i,       // 写数据
    output reg[31:0] data_o        // 读数据
);
```

### 3.3 Timer（`rtl/perips/timer.v`）

可编程定时器，支持中断。

```verilog
module timer(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    output wire int_sig_o          // 中断输出 → CPU int_i[0]
);
```

**寄存器映射（偏移地址）：**

| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| `0x00` | `CTRL` | bit[0]=使能, bit[1]=中断使能, bit[2]=中断挂起 |
| `0x04` | `COUNT` | 当前计数值（只读） |
| `0x08` | `VALUE` | 定时到期值 |

**中断路径：** `timer.int_sig_o` → `tinyriscv_soc_top.timer0_int` → `int_flag[0]` → `tinyriscv.int_i`

### 3.4 UART（`rtl/perips/uart.v`）

异步串口，支持可配置波特率。

```verilog
module uart(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    output wire tx_pin,            // → SoC 顶层引脚
    input wire rx_pin              // ← SoC 顶层引脚
);
```

**寄存器映射（偏移地址）：**

| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| `0x00` | `CTRL` | bit[0]=TX使能, bit[1]=RX使能 |
| `0x04` | `STATUS` | bit[0]=TX忙, bit[1]=RX完成 |
| `0x08` | `BAUD` | 波特率分频系数 |
| `0x0C` | `TXDATA` | 发送数据寄存器 |
| `0x10` | `RXDATA` | 接收数据寄存器 |

### 3.5 GPIO（`rtl/perips/gpio.v`）

2 路双向通用 IO。

```verilog
module gpio(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    input wire[1:0] io_pin_i,      // ← 外部 inout 引脚（经三态分离）
    output wire[31:0] reg_ctrl,    // → SoC 顶层，驱动三态逻辑
    output wire[31:0] reg_data     // → SoC 顶层，驱动输出值
);
```

**寄存器映射（偏移地址）：**

| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| `0x00` | `CTRL` | 每 2 位控制 1 路 IO：`2'b00`=高阻，`2'b01`=输出，`2'b10`=输入 |
| `0x04` | `DATA` | IO 输入/输出数据 |

**三态引脚处理（SoC 顶层）：**

```verilog
assign gpio[0] = (gpio_ctrl[1:0] == 2'b01) ? gpio_data[0] : 1'bz;
assign io_in[0] = gpio[0];
assign gpio[1] = (gpio_ctrl[3:2] == 2'b01) ? gpio_data[1] : 1'bz;
assign io_in[1] = gpio[1];
```

GPIO 模块自身只处理寄存器读写逻辑；三态驱动在顶层通过 `assign` 实现，`inout` 端口不能穿越模块边界内部化。

### 3.6 SPI（`rtl/perips/spi.v`）

SPI 主机模式，支持 CPOL/CPHA 配置。

```verilog
module spi(
    input wire clk,
    input wire rst,
    input wire we_i,
    input wire[31:0] addr_i,
    input wire[31:0] data_i,
    output reg[31:0] data_o,
    output reg spi_mosi,           // 主出从入 → SoC 顶层
    input wire spi_miso,           // 主入从出 ← SoC 顶层
    output wire spi_ss,            // 片选 → SoC 顶层
    output reg spi_clk             // SPI 时钟 → SoC 顶层
);
```

**寄存器映射（偏移地址）：**

| 偏移 | 寄存器 | 说明 |
|------|--------|------|
| `0x00` | `CTRL` | bit[0]=使能, bit[1]=CPOL, bit[2]=CPHA, bit[3]=SS, bit[15:8]=时钟分频 |
| `0x04` | `DATA` | 发送数据（写触发传输） |
| `0x08` | `STATUS` | bit[0]=忙 |

---

## 4. SoC 顶层对外引脚

删除 Timer/GPIO/SPI 之前，`tinyriscv_soc_top` 的完整外部引脚：

```verilog
module tinyriscv_soc_top(
    input  wire       clk,
    input  wire       rst,
    output reg        over,           // 测试完成（仿真用）
    output reg        succ,           // 测试通过（仿真用）
    output wire       halted_ind,     // CPU 已被 JTAG halt
    input  wire       uart_debug_pin, // 串口下载使能
    output wire       uart_tx_pin,    // UART TX
    input  wire       uart_rx_pin,    // UART RX
    inout  wire [1:0] gpio,           // GPIO 双向引脚
    input  wire       jtag_TCK,
    input  wire       jtag_TMS,
    input  wire       jtag_TDI,
    output wire       jtag_TDO,
    input  wire       spi_miso,
    output wire       spi_mosi,
    output wire       spi_ss,
    output wire       spi_clk
);
```

**中断信号路径：**

```
timer.int_sig_o → timer0_int → int_flag[0] → tinyriscv.int_i
                                              （int_flag[7:1] 固定为 0）
```
