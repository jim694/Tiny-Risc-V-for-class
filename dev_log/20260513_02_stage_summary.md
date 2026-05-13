# 阶段汇总：外设集成与存储器访问完善

**日期：** 2026-05-13  
**Tag：** v0.3-peripheral-stall  
**分支：** `claude`

---

## 一、本阶段完成内容

### 1.1 外设集成

| 外设 | 总线地址 | 状态 |
|------|---------|------|
| PWM（4 通道） | `0x6xxx_xxxx`（Slave 6）| RTL 完成，波形验证通过，待上板 |
| I2C Master | `0x7xxx_xxxx`（Slave 7）| 设计文档完成，RTL 待实现 |

PWM 寄存器映射：
- `A[3:0]`（32-bit）：各通道总周期，地址 `0x600x_0000`
- `B[3:0]`（32-bit）：各通道高电平时长，地址 `0x601x_0000`
- `C`（4-bit）：通道使能，地址 `0x6004_0000`
- 计数器写 A/B 时立即清零（方案一），输出 `pwm_o[i] = C[i] & (A[i]!=0) & (cnt[i]<B[i])`

### 1.2 存储器访问 Stall 完善（核心工作）

**背景：** ROM/RAM 迁移片外后，所有取指和数据访问经过 8-bit 串行 bridge（每笔事务 8 个时钟周期）。原始 stall 机制在多种场景下会造成指令跳过（吞指令）。

#### 矛盾一：RAM 数据访问抢占取指

m0（EX lw/sw）优先级高于 m1（IF 取指），RAM 事务期间 m1 被阻。事务完成后 pipeline 推进，但 `s0_rdata_o` 持有的是旧指令，下一条指令从未被取。

**修复：** `need_fetch_r` 机制。RAM 事务（S_LATCH `mem_sel_r=1`）完成后不释放 stall，强制在 S_IDLE 再做一次 ROM 取指（地址来自 `s0_addr_i`），ROM 取指完成后才置 `transaction_done`。

#### 矛盾二：m0 访问非 bridge 外设（PWM/UART），bridge 完全空闲

sw 到 PWM 时，m0 占总线访问 s6，`s0_cs_i=s1_cs_i=0`，bridge 空闲，`stall_o=0`，PC 连续推进两拍，中间那条指令被跳过。

**最终修复（飞线消除版）：**
- `rib.v`：`s0_addr_o` 默认值由 `ZeroWord` 改为 `{4'h0, m1_addr_i[27:0]}`。m1 始终访问 s0（ROM），默认输出 m1 的 PC，使 bridge 在 m0 占总线时仍能通过 `s0_addr_i` 看到正确 PC。
- `rib_mem_bridge.v`：bridge 在 S_IDLE 且非自由拍时始终发起事务（`stall_o = (state!=S_IDLE) || !transaction_done`），不再依赖 `any_cs`。m0 访问 PWM 时 `s0_cs_i=s1_cs_i=0`，bridge 自动以 `s0_addr_i`（= PC）发起 ROM 取指。

#### addr_match 误判修复

原先 S_LATCH 用 `s0_addr_i[9:2]` 做 ROM 地址比对。m0 占总线时 `s0_addr_i=ZeroWord`，导致 addr_match 误判为 0，取指结果被丢弃并触发一次无效自由拍，PC 跳过一条指令。

**修复（已被飞线消除版覆盖）：** addr_match 恢复使用 `s0_addr_i[9:2]`，因 RIB 默认输出 m1 的 PC，该值在 m0 占总线时始终有效。

#### 设计原则：无飞线

最终设计中，`rib_mem_bridge` 仅通过 RIB 从设备接口（`s0_*`、`s1_*`）感知外部世界，不持有任何绕过 RIB 的直接 CPU 信号（之前曾引入 `pc_i` 和 `force_fetch_i`，已通过上述 RIB 架构改进彻底消除）。

### 1.3 Stall 机制现状

```verilog
// rib_mem_bridge.v
stall_o = (state != S_IDLE) || !transaction_done
```

| 触发场景 | 处理 | 周期数 |
|---------|------|-------|
| 普通取指（m1→ROM）| 正常 ROM 事务 | 8+1 |
| lw/sw → RAM | RAM 事务 + 强制 ROM 取指 | 8+8+1 |
| sw/lw → 外设 | bridge 自动 ROM 取指 | 8+1 |
| 分支 | addr_match=0 丢弃，新 PC 重取 | 重取 |

### 1.4 仿真框架修复

- `tb/tinyriscv_soc_tb.v`：`$readmemh` 目标从孤立外部实例改为 `tinyriscv_soc_top_0.u_fpga_mem_bridge._rom`；删除孤立 `fpga_mem_bridge` 实例
- `sim/compile_rtl.py`：新增 `pwm.v`；删除已废弃的 `ram/rom/timer/gpio/spi/gen_buf.v`

### 1.5 JTAG 接口

恢复 JTAG（jtag_top + jtag_driver + jtag_dm），为潜在流片需求保留。TCK/TMS/TDI/TDO 绑定到空闲 GPIO 引脚并加 PULLUP；TCK 添加 `CLOCK_DEDICATED_ROUTE FALSE` 消除布线 critical warning。

### 1.6 顶层 XDC 引脚约束（全部完成）

| 端口 | 引脚 | 备注 |
|------|------|------|
| `clk` | Y18 | 50MHz |
| `rst` | F20 | |
| `succ` | F19 | |
| `over` | F14 | |
| `uart_tx_pin` | G16 | |
| `uart_rx_pin` | G15 | |
| `uart_debug_pin` | M13 | |
| `pwm_o[0]` | E21 | LED2 |
| `pwm_o[1]` | D20 | LED3 |
| `pwm_o[2]` | C20 | LED4 |
| `pwm_o[3]` | E14 | LED1 |
| `halted_ind` | D15 | JTAG halt 状态 |
| `jtag_TCK` | A18 | PULLUP，CLOCK_DEDICATED_ROUTE FALSE |
| `jtag_TMS` | D14 | |
| `jtag_TDI` | B13 | |
| `jtag_TDO` | C13 | |

I2C（`io_scl`/`io_sda`）已注释保留，待 I2C RTL 实现后解注释。

---

## 二、验证状态

| 验证项 | 状态 |
|--------|------|
| Basic_Inst_Example 24/24 | ✅ PASS |
| JTAG 仿真（TEST_JTAG）| ✅ jtag test pass |
| PWM 波形仿真 | ✅ 逻辑正常 |
| PWM 上板 | ⏳ 待执行 |
| I2C RTL | ⏳ 待实现 |

---

## 三、Vivado 工程文件清单

Design Sources（20 个）：

| 分类 | 文件 |
|------|------|
| SoC 顶层 | `rtl/soc/tinyriscv_soc_top.v` |
| CPU 核 | `rtl/core/defines.v`（Global Include） |
| | `rtl/core/tinyriscv.v`, `pc_reg.v`, `ctrl.v`, `if_id.v` |
| | `rtl/core/id.v`, `id_ex.v`, `ex.v`, `regs.v` |
| | `rtl/core/rib.v`, `div.v`, `clint.v`, `csr_reg.v` |
| 外设 | `rtl/perips/uart.v`, `rtl/perips/pwm.v` |
| 桥接 | `rtl/bridge/rib_mem_bridge.v`, `rtl/bridge/fpga_mem_bridge.v` |
| 调试 | `rtl/debug/uart_debug.v`, `rtl/debug/jtag_top.v` |
| | `rtl/debug/jtag_driver.v`, `rtl/debug/jtag_dm.v` |
| 工具 | `rtl/utils/gen_dff.v`, `rtl/utils/full_handshake_rx.v`, `rtl/utils/full_handshake_tx.v` |

约束：`fpga/tinyriscv_soc_top.xdc`

---

## 四、关键约束（不可更改）

| 项目 | 值 |
|------|-----|
| 外部 ROM | 256×32-bit（1KB）|
| 外部 RAM | 16×32-bit（64B）|
| Bridge 串行接口 | 8-bit IN + 8-bit OUT |
| 每条指令取指 | 8+1 个时钟周期 |
| lw/sw → RAM | 16+1 个时钟周期 |
| lw/sw → 外设 | 8+1 个时钟周期 |

---

## 五、下一步

1. PWM 上板验证（使用 `tests/Other_Example/PWM/PWM_inst.data`）
2. I2C RTL 实现与仿真
3. 完整系统上板集成测试