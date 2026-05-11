# 删除 Timer / SPI / GPIO 外设及仿真验证

**日期：** 2026-05-11
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）
**分支：** claude

---

## 1. 目标

从 TinyRISCV SoC 设计中移除 Timer、SPI、GPIO 三个外设模块，保留 ROM、RAM、UART，同时确保处理器核心功能不受影响，48 条 ISA 测试全部通过。

---

## 2. 影响分析

删除前，三个外设在设计中的角色：

| 外设 | 总线位置 | 地址范围 | 特殊连接 |
|------|---------|---------|---------|
| Timer | Slave 2 | `0x2000_0000`+ | `int_sig_o` → CPU 中断输入 `int_i[0]` |
| GPIO | Slave 4 | `0x4000_0000`+ | `inout gpio[1:0]` 顶层引脚；三态 assign 逻辑 |
| SPI | Slave 5 | `0x5000_0000`+ | `spi_mosi/miso/ss/clk` 顶层引脚 |

**关键依赖：** Timer 的中断信号 `timer0_int` 连接到 `int_flag[0]`，再送入 CPU 的 `int_i`。删除 Timer 时需将 `int_flag` 直接置为 `INT_NONE`（8'h0），否则 CPU 会接到悬空的中断线。

---

## 3. 修改内容

### 3.1 `rtl/core/rib.v`

**变更：** 删除 Slave 2（Timer）、Slave 4（GPIO）、Slave 5（SPI）的总线接口。

具体删除项：
- 参数 `slave_2`、`slave_4`、`slave_5`
- 端口声明：`s2_*`、`s4_*`、`s5_*`（各 4 个信号：addr/data_o/data_i/we）
- 在 `always @ (*)` 初始化块中对 `s2_`/`s4_`/`s5_` 的默认赋值
- 在 grant0 / grant1 / grant2 / grant3 四个 case 分支中，与 `slave_2`/`slave_4`/`slave_5` 对应的 case 子句（共 12 处）

**保留：** Slave 0（ROM）、Slave 1（RAM）、Slave 3（UART）及其所有逻辑不变。

删除后 RIB 端口列表：

```verilog
// 从设备接口（保留）
s0_*  // ROM  (addr 0x0xxx_xxxx)
s1_*  // RAM  (addr 0x1xxx_xxxx)
s3_*  // UART (addr 0x3xxx_xxxx)
```

> **地址兼容性：** UART 仍使用 `slave_3 = 4'b0011`，响应地址 `0x3xxx_xxxx`，软件无需修改。

### 3.2 `rtl/soc/tinyriscv_soc_top.v`

**变更 1：顶层端口** — 删除 `gpio[1:0]`（inout）、`spi_miso/mosi/ss/clk`

```verilog
// 删除后，外设相关的顶层引脚仅保留：
output wire uart_tx_pin,
input  wire uart_rx_pin,
```

**变更 2：内部 wire 声明** — 删除 `s2_*`、`s4_*`、`s5_*`、`timer0_int`、`io_in`、`gpio_ctrl`、`gpio_data`

**变更 3：中断信号** — 将 Timer 中断驱动改为常量零

```verilog
// 修改前
wire timer0_int;
assign int_flag = {7'h0, timer0_int};

// 修改后
assign int_flag = `INT_NONE;   // 8'h0，无中断源
```

**变更 4：模块例化** — 删除以下三个例化块

```verilog
// 已删除
timer timer_0 ( ... );
gpio  gpio_0  ( ... );
spi   spi_0   ( ... );
```

**变更 5：GPIO 三态逻辑** — 删除以下 assign 语句

```verilog
// 已删除
assign gpio[0] = (gpio_ctrl[1:0] == 2'b01) ? gpio_data[0] : 1'bz;
assign io_in[0] = gpio[0];
assign gpio[1] = (gpio_ctrl[3:2] == 2'b01) ? gpio_data[1] : 1'bz;
assign io_in[1] = gpio[1];
```

**变更 6：RIB 例化连线** — 删除 `s2_*`、`s4_*`、`s5_*` 连接，保留 `s0_*`、`s1_*`、`s3_*`

---

## 4. 未改动的内容

| 项目 | 说明 |
|------|------|
| `rtl/perips/timer.v` | 文件保留，模块定义存在但不再被例化 |
| `rtl/perips/gpio.v` | 同上 |
| `rtl/perips/spi.v` | 同上 |
| `sim/compile_rtl.py` | 仍编译三个外设文件（iverilog 允许未例化的模块定义存在） |
| `tb/tinyriscv_soc_tb.v` | 无需修改（testbench 仅连接 clk/rst/uart_debug_pin） |
| CPU 核心（`rtl/core/`） | 零改动 |
| ROM / RAM / UART | 零改动 |

---

## 5. 仿真验证

### 5.1 执行命令

```bash
cd sim/
python test_all_isa.py
```

### 5.2 结果

```
../tests/isa/generated\rv32ui-p-add.bin      PASS
../tests/isa/generated\rv32ui-p-addi.bin     PASS
...（共 39 条 RV32I 指令）...
../tests/isa/generated\rv32um-p-div.bin      PASS
...（共 8 条 RV32M 指令）...
../tests/isa/generated\rv32um-p-remu.bin     PASS
Congratulation, All PASS...
```

**结论：48/48 全部 PASS。** 删除 Timer、SPI、GPIO 后处理器核心功能完全正常。

---

## 6. 修改后的 SoC 结构

```
                         RIB 总线（4主3从）
                        /      |      |      \
                      M0      M1      M2      M3
                  (CPU访存) (CPU取指) (JTAG) (串口下载)
                        \      |      |      /
                         ──────────────────
                     S0         S1         S3
                    ROM         RAM        UART
               (0x0xxx_xxxx) (0x1xxx_xxxx) (0x3xxx_xxxx)
```

顶层对外引脚（删减后）：

```verilog
module tinyriscv_soc_top(
    input  wire clk,
    input  wire rst,
    output reg  over,
    output reg  succ,
    output wire halted_ind,
    input  wire uart_debug_pin,
    output wire uart_tx_pin,
    input  wire uart_rx_pin,
    input  wire jtag_TCK,
    input  wire jtag_TMS,
    input  wire jtag_TDI,
    output wire jtag_TDO
);
```
