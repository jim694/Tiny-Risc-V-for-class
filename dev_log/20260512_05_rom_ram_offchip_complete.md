# ROM/RAM 片外迁移完成记录

**日期：** 2026-05-12  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）  
**前置文档：** `20260511_05_rom_ram_offchip_plan.md`、`20260511_06_rom_ram_bridge_redesign.md`、`20260512_01_bridge_stall_impl.md`

---

## 一、功能概述

将原来片内的 ROM（4096×32-bit）和 RAM（4096×32-bit）完全移除，通过 8-bit 串行桥接接口迁移至 FPGA 侧。SoC 芯片片内不再保留任何存储阵列。

**目标规格（硬性约束）：**

| 项目 | 规格 |
|------|------|
| 片内 ROM/RAM | 无 |
| 外部 ROM | 256×32-bit（1KB）|
| 外部 RAM | 16×32-bit（64B）|
| 接口 | 8-bit OUT（SoC→FPGA）+ 8-bit IN（FPGA→SoC）|

---

## 二、最终架构

```
┌─────────────── SoC 芯片 ───────────────┐     ┌──── FPGA 侧 ─────────────────────┐
│                                        │     │                                  │
│  RIB 总线                               │     │  fpga_mem_bridge                 │
│  Slave 0 (ROM, s0_cs_o) ──┐            │     │  ┌───────────────────────────┐   │
│                            ├── rib_mem  │8bit │  │ 6状态FSM                  │   │
│  Slave 1 (RAM, s1_cs_o) ──┘  _bridge ──┼────►├─►│ _rom[0:255]（256×32-bit） │   │
│                               stall_o  │8bit │  │ _ram[0:15] （16×32-bit）  │   │
│  CPU ◄──── Hold_Freeze ───────────────  │◄────┤◄─│                           │   │
│                                        │     │  └───────────────────────────┘   │
└────────────────────────────────────────┘     └──────────────────────────────────┘
```

---

## 三、SoC 侧桥接模块（rib_mem_bridge.v）

### 3.1 FSM 设计

7 状态，8 周期/事务（理论下限）：

```
S_IDLE(pending+CTRL) → S_SEND_ADDR → S_DATA0 → S_DATA1 → S_DATA2 → S_DATA3 → S_LATCH → S_IDLE(free)
```

**优化说明：** 原设计有独立的 S_SEND_CTRL 状态（共 8 状态，9 周期）。由于 pending=1 时 CPU 已被 Hold_Freeze 冻住，地址稳定，CTRL 字节与地址捕获直接在 S_IDLE 完成，节省 1 个周期。

### 3.2 8 周期时序

```
T  SoC 状态       SoC→FPGA      FPGA 状态      FPGA→SoC
0  S_IDLE         CTRL          S_IDLE          0
1  S_SEND_ADDR    ADDR          S_RECV_ADDR     0
2  S_DATA0        WDAT[7:0]     S_DATA0         rdata[7:0]
3  S_DATA1        WDAT[15:8]    S_DATA1         rdata[15:8]    ← SoC 采
4  S_DATA2        WDAT[23:16]   S_DATA2         rdata[23:16]   ← SoC 采
5  S_DATA3        WDAT[31:24]   S_DATA3         rdata[31:24]   ← SoC 采
6  S_LATCH        0             S_IDLE          0              ← SoC 采并锁存
7  S_IDLE(free)   —             —               —              CPU 推进
```

**CTRL 字节格式：**

| bit[7] | bit[6] | bit[5] | bit[4:0] |
|--------|--------|--------|---------|
| 帧起始（1）| mem_sel（0=ROM，1=RAM）| we（0=读，1=写）| 保留（0）|

### 3.3 分支跳转处理（addr_match）

**Bug 根因（通过 Vivado 波形确认）：**  
分支执行时，jump_flag 优先级高于 Hold_Freeze，PC 跳转至新地址，但 bridge 仍在为旧地址完成事务。free cycle 时 if_id 采到旧指令，跳转目标的第一条指令被直接覆盖。

**修复方案（方案 A，最小改动）：**  
在 S_LATCH 时比对当前 `s0_addr_i[9:2]`（新 PC）与 `addr_r`（事务开始时捕获的旧 PC）：

```verilog
wire [7:0] cur_word_addr = mem_sel_r ? s1_addr_i[9:2] : s0_addr_i[9:2];
wire addr_match = (cur_word_addr == addr_r);

S_LATCH: begin
    if (addr_match) begin
        // 地址匹配：正常锁存，授予 free cycle
        if (mem_sel_r) s1_rdata_o <= {ext_in_i, rdata_buf};
        else           s0_rdata_o <= {ext_in_i, rdata_buf};
        transaction_done <= 1'b1;
    end
    // 地址不匹配：静默丢弃，pending 立即触发重取
    state <= S_IDLE;
end
```

**设计原则说明：** 方案 B（bridge 接收 jump_flag 输入）被排除，因为 jump_flag 是 CPU 内部信号，不应绕过总线直连外设。

### 3.4 stall 信号

```verilog
wire pending = any_cs && (state == S_IDLE) && !transaction_done;
assign stall_o = (state != S_IDLE) || pending;
```

`stall_o` 连接至 CPU 的 `rib_hold_flag_i`，经 ctrl.v 输出 `Hold_Freeze`（3'b100），冻结全部流水线寄存器。

---

## 四、FPGA 侧桥接模块（fpga_mem_bridge.v）

6 状态 FSM，同步于同一时钟：

```
S_IDLE     → S_RECV_ADDR → S_DATA0 → S_DATA1 → S_DATA2 → S_DATA3 → S_IDLE
```

**关键实现：** S_RECV_ADDR 中使用 `ext_in_i`（而非已注册的 `addr_r`）直接作为存储体读地址，避免 1 拍额外延迟：

```verilog
wire [31:0] rdata_from_ext = mem_sel_r ? _ram[ext_in_i[3:0]] : _rom[ext_in_i[7:0]];
```

仿真中通过 testbench 的 `$readmemh` 初始化：

```verilog
$readmemh("inst.data", u_fpga_mem._rom);
```

---

## 五、流水线改造

### 5.1 Hold_Freeze 新增

原 `gen_pipe_dff` 的 `hold_en=1` 只能冲刷为 NOP，无法冻结。新增 `Hold_Freeze = 3'b100`，拆分为两个独立控制端：

| 控制端 | 语义 | 触发条件 |
|--------|------|---------|
| `flush_en` | 输出 NOP（冲刷）| Hold_If / Hold_Id（分支、MUL/DIV）|
| `freeze_en` | 保持当前值 | Hold_Freeze（bridge stall）|

### 5.2 涉及文件

| 文件 | 改动 |
|------|------|
| `rtl/core/defines.v` | 新增 `` `Hold_Freeze 3'b100 `` |
| `rtl/utils/gen_dff.v` | hold_en → flush_en + freeze_en |
| `rtl/core/if_id.v` | 更新 hold 逻辑（精确匹配）|
| `rtl/core/id_ex.v` | 更新 hold 逻辑（精确匹配）|
| `rtl/core/ctrl.v` | bridge stall → Hold_Freeze |

### 5.3 RIB 新增片选信号

原 RIB 总线对未选中从设备输出全零，与地址 0 的有效读取无法区分。在 `rtl/core/rib.v` 为 Slave 0/1 新增 `s0_cs_o` / `s1_cs_o` 片选输出，`rib_mem_bridge` 以此区分"ROM 地址 0 的有效读"和"未选中"。

---

## 六、Vivado 编译 include 路径说明

Vivado 综合/仿真时，各文件的 `` `include "defines.v" `` 需使用相对于该文件自身的路径，而非依赖 include 目录配置。已按如下规则修改：

| 文件 | 修改前 | 修改后 |
|------|--------|--------|
| `rtl/bridge/fpga_mem_bridge.v` | `` `include "defines.v" `` | `` `include "../core/defines.v" `` |
| `rtl/bridge/rib_mem_bridge.v` | `` `include "defines.v" `` | `` `include "../core/defines.v" `` |
| `tb/tinyriscv_soc_tb.v` | `` `include "defines.v" `` | `` `include "../rtl/core/defines.v" `` |

> **注意：** iverilog 仿真时通过 `-I rtl/core` 添加 include 路径，不受此修改影响；原路径写法对 iverilog 仍然有效。Vivado 不使用 `-I` 参数，因此需要显式相对路径。

---

## 七、SoC 顶层改动（tinyriscv_soc_top.v）

- 删除 `u_rom`、`u_ram` 例化
- 新增顶层端口 `ext_mem_out[7:0]`（SoC→FPGA）、`ext_mem_in[7:0]`（FPGA→SoC）
- 新增 `u_rib_mem_bridge` 例化，接管 Slave 0/1 双接口
- `cpu_hold = mem_bridge_stall`（bridge 的 `stall_o`）

---

## 八、性能

| 指令类型 | 原设计 | 本次实现 |
|----------|--------|---------|
| 纯 ALU | 1 周期/条 | 8 周期/条 |
| lw / sw | 1 周期/条 | 16 周期/条（IF+EX 串行，单通道约束）|
| 分支（taken）| 1 周期 + 冲刷 | 8 周期 + 重取（addr_match 丢弃旧数据）|

8 周期为该协议的理论下限（1字节CTRL + 1字节ADDR + 1拍延迟 + 4字节数据 + 1拍free cycle）。

---

## 九、验证结果

**测试集：** Basic_Inst_Example（24 个用例，来自 RISC-V ISA 测试套件）  
**结果：24/24 PASS**

```
add andi auipc beq bge bgeu blt bltu bne div divu
jal jalr lui ori rem remu simple slli slti sltiu srai srli xori
全部通过
```

相比修改初期（WIP 提交，仅 1/24 通过），经过以下关键修复逐步达到全通：

1. `gen_pipe_dff` 语义修正（freeze vs flush）→ 14/24
2. `addr_match` 分支跳转修复 → 24/24