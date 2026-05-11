# ROM/RAM 模块学习与片外迁移计划

**日期：** 2026-05-11
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、当前 ROM/RAM 模块学习

### 1.1 参数定义（`rtl/core/defines.v`）

```verilog
`define RomNum 4096   // ROM 深度（字数）→ 4096 × 32-bit = 16KB
`define MemNum 4096   // RAM 深度（字数）→ 4096 × 32-bit = 16KB
`define MemBus    31:0
`define MemAddrBus 31:0
```

### 1.2 ROM 模块（`rtl/perips/rom.v`）

```verilog
module rom(
    input  wire        clk,
    input  wire        rst,
    input  wire        we_i,           // 写使能
    input  wire[31:0]  addr_i,         // 字节地址（全 32 位）
    input  wire[31:0]  data_i,         // 写数据
    output reg [31:0]  data_o          // 读数据
);
    reg[31:0] _rom[0:4095];            // 片内存储体

    // 写：同步（posedge clk）
    always @ (posedge clk) begin
        if (we_i == `WriteEnable)
            _rom[addr_i[31:2]] <= data_i;
    end

    // 读：组合逻辑（always @(*)）
    always @ (*) begin
        if (rst == `RstEnable) data_o = 32'h0;
        else                   data_o = _rom[addr_i[31:2]];
    end
endmodule
```

**关键特性：**

| 项目 | 说明 |
|------|------|
| 存储体 | `reg[31:0] _rom[0:4095]`（片内 BRAM 推断） |
| 地址方式 | **字地址**，取 `addr_i[31:2]`（低 2 位舍弃，4 字节对齐）|
| 读操作 | **组合逻辑**，零延迟，无需等待 |
| 写操作 | 同步，上升沿触发 |
| 初始化 | 仿真中由 testbench `$readmemh("inst.data", u_rom._rom)` 加载 |
| 总线接口 | RIB Slave 0，地址 `0x0xxx_xxxx` |

ROM 逻辑上是"只读"（程序存储），但接口保留 `we_i` 是为了兼容 RIB 总线统一的从设备格式，实际运行中 CPU 不对 ROM 发起写操作（只有 `uart_debug` 烧写时才写）。

### 1.3 RAM 模块（`rtl/perips/ram.v`）

```verilog
module ram(
    input  wire        clk,
    input  wire        rst,
    input  wire        we_i,
    input  wire[31:0]  addr_i,
    input  wire[31:0]  data_i,
    output reg [31:0]  data_o
);
    reg[31:0] _ram[0:4095];            // 片内存储体

    always @ (posedge clk) begin
        if (we_i == `WriteEnable)
            _ram[addr_i[31:2]] <= data_i;
    end
    always @ (*) begin
        if (rst == `RstEnable) data_o = 32'h0;
        else                   data_o = _ram[addr_i[31:2]];
    end
endmodule
```

ROM 与 RAM 的 RTL 结构**完全相同**，差异仅在于：
- 存储体名称 `_rom` vs `_ram`
- 参数引用 `RomNum` vs `MemNum`
- 总线挂载：Slave 0（`0x0xxx_xxxx`）vs Slave 1（`0x1xxx_xxxx`）

### 1.4 读时序分析

```
         clk   ___     ___     ___
               |   |___|   |___|
  addr_i  ─────┤ A           │
  data_o  ─────────┤ D(A)    │    ← 组合输出，无时钟延迟
```

读为纯组合逻辑（`always @(*)`），一旦 `addr_i` 稳定，`data_o` 立即有效。这与 RIB 总线的无应答（no-ACK）设计匹配——总线仲裁器不等待从设备就绪信号，直接假定数据在同周期可用。

写为同步：

```
         clk   ___         ___
               |   |_______|
  we_i    ─────┤ 1         │
  addr_i  ─────┤ A         │
  data_i  ─────┤ D         │
  _mem[A] ─────────────────┤ D  ← 下一上升沿后有效
```

---

## 二、片外迁移动机

将 ROM/RAM 从处理器核片内移至 FPGA 侧（片外），主要目的：

1. **灵活替换存储介质**：片外可选用 SRAM、Flash 或 FPGA Block RAM 独立 IP
2. **独立调整容量**：不受处理器核综合约束，可按需配置深度/宽度
3. **教学实验目的**：理解片内 BRAM 与片外存储的接口桥接设计
4. **课程需求**：将存储器从 SoC 顶层剥离，形成清晰的内/外部边界

---

## 三、目标参数

| 存储器 | 原始大小 | 迁移后大小 |
|--------|---------|-----------|
| ROM | 4096 × 32-bit（16KB）| **256 × 32-bit（1KB）** |
| RAM | 4096 × 32-bit（16KB）| **16 × 32-bit（64B）** |

地址范围说明（迁移后）：

| 存储器 | 地址区间 | 字地址位宽 | 最大字节地址 |
|--------|---------|-----------|------------|
| 外部 ROM | `0x0000_0000` ~ `0x0000_03FF` | 8-bit（[9:2]）| `0x3FC` |
| 外部 RAM | `0x1000_0000` ~ `0x1000_003F` | 4-bit（[5:2]）| `0x1000_003C` |

---

## 四、架构设计

### 4.1 接口约束与设计原则

- **物理接口**：SoC 与 FPGA 之间共用**一对** 8-bit 串行总线（16 根引脚）
  - `ext_mem_out[7:0]`：SoC → FPGA
  - `ext_mem_in[7:0]`：FPGA → SoC
- **单一 SoC 桥接模块**（`rib_mem_bridge`）：直接继承 Slave 0（ROM）和 Slave 1（RAM）的完整 RIB 接口，取代原来的 `u_rom` / `u_ram` 例化
- **单一 FPGA 桥接模块**（`fpga_mem_bridge`）：内含 ROM 和 RAM 两块存储体，通过帧协议区分
- **存储器容量**：ROM 256×32-bit（1KB），RAM 16×32-bit（64B）

### 4.2 总体结构

```
┌──────────────────────── SoC 芯片 ──────────────────────────────────┐  ┌──── FPGA 侧 ──────────────────────┐
│                                                                    │  │                                   │
│  RIB 总线                                                           │  │  fpga_mem_bridge                  │
│  Slave 0 (s0_*, s0_cs_o) ──┐                                       │  │  ┌─────────────────────────────┐  │
│                             ├──► rib_mem_bridge  ext_mem_out[7:0] ──┼─►├─►│ 6状态机                      │  │
│  Slave 1 (s1_*, s1_cs_o) ──┘    stall_o → cpu_hold→CPU hold        │  │  │ _rom[0:255]（256×32b = 1KB） │  │
│                                                  ext_mem_in[7:0]  ◄─┼─◄├─◄│ _ram[0:15]（16×32b = 64B）  │  │
└────────────────────────────────────────────────────────────────────┘  │  └─────────────────────────────┘  │
                                                                        └───────────────────────────────────┘
```

**引脚对比：**

| 方案 | 引脚数 |
|------|--------|
| 宽并行接口 | 144 根（ROM 74 + RAM 70）|
| **8-bit 串行，统一桥接** | **16 根**（ext_mem_out 8 + ext_mem_in 8）|

### 4.3 关键约束：ctrl.v 必须修改

TinyRISCV 中 `ctrl.v` 将 `hold_flag_rib_i` 映射为 `Hold_Pc`（仅冻结 PC）：

```verilog
// ctrl.v 原始代码
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Pc;   // 只冻结PC，不冻结 if_id / id_ex
```

- `Hold_Pc = 3'b001`：pc_reg 冻结 ✓，但 if_id 和 id_ex **仍在推进**
- 原始设计依赖此行为：M0 load 只需冻结 PC 1 拍，RAM 组合读立即返回数据，流水线顺利前进
- **多周期桥接不兼容**：8 拍等待期间，if_id 持续推进无效指令，导致目标指令被冲出流水线，CPU 永远无法完成取指或 load

**必须修改**：将 `Hold_Pc` 改为 `Hold_Id`，冻结整条流水线：

```verilog
// ctrl.v 修改后
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Id;   // 冻结 PC + if_id + id_ex
```

`Hold_Id = 3'b011` 使 if_id 和 id_ex 均保持当前值，整条流水线在桥接事务期间静止等待。

### 4.4 RIB 新增片选信号

**问题**：RIB 对未选中的从设备输出全零（addr=0，we=0）。ROM 读地址 0（复位取指）信号与"未选中"完全相同，桥接模块无法区分。

**解决**：在 `rtl/core/rib.v` 为 Slave 0 和 Slave 1 各新增 1-bit 片选输出：

```verilog
output reg s0_cs_o,   // Slave 0 被选中时为 1
output reg s1_cs_o,   // Slave 1 被选中时为 1
```

在路由 `always @(*)` 中，默认为 0，访问对应 slave 时置 1。这是 rib.v 的**唯一额外改动**，不影响任何现有路由逻辑。

### 4.5 帧协议（8-bit 串行，CTRL 区分 ROM/RAM）

每次内存访问触发一帧，SoC 桥接在 S_SEND_CTRL 状态捕获地址后开始发送：

```
SoC→FPGA  ext_mem_out[7:0]              FPGA→SoC  ext_mem_in[7:0]
──────────────────────────────────────────────────────────────────
S_SEND_CTRL  CTRL={1'b1,mem_sel,we,5'b0}   8'h00
S_SEND_ADDR  ADDR=word_addr[7:0]            8'h00  ← FPGA此拍读存储器→输出rdata[7:0]
S_DATA0      WDAT[7:0]                       RDAT[7:0]
S_DATA1      WDAT[15:8]                      RDAT[15:8]
S_DATA2      WDAT[23:16]                     RDAT[23:16]
S_DATA3      WDAT[31:24]                     RDAT[23:16]（SoC在S_LATCH采样）
S_LATCH      8'h00                           RDAT[31:24]  ← SoC锁存完整rdata
```

**CTRL 字节：**

| bit | 含义 |
|-----|------|
| [7] | 1（帧起始标志，IDLE 期间 ext_out=0，FPGA 以此区分空闲与帧头）|
| [6] | mem_sel：0=ROM(Slave0)，1=RAM(Slave1) |
| [5] | we：0=读，1=写 |
| [4:0] | 保留（全 0）|

**地址编码**：`word_addr = byte_addr[9:2]`（取低 8 位），8-bit 覆盖 ROM 256 字和 RAM 16 字。

### 4.6 SoC 侧桥接模块（`rtl/bridge/rib_mem_bridge.v`）

直接继承 Slave 0 和 Slave 1 两套 RIB 接口：

```verilog
module rib_mem_bridge (
    input  wire        clk, rst,
    // RIB Slave 0（ROM）
    input  wire [31:0] s0_addr_i, s0_wdata_i,
    output reg  [31:0] s0_rdata_o,
    input  wire        s0_we_i, s0_cs_i,
    // RIB Slave 1（RAM）
    input  wire [31:0] s1_addr_i, s1_wdata_i,
    output reg  [31:0] s1_rdata_o,
    input  wire        s1_we_i, s1_cs_i,
    // 8-bit 串行接口
    output reg  [7:0]  ext_out_o,
    input  wire [7:0]  ext_in_i,
    // CPU 暂停
    output wire        stall_o
);
```

**8 状态 FSM：**

```
S_IDLE
  │ 触发条件：any_cs && !transaction_done（pending信号立即拉高stall）
  │ 不捕获地址（等下一拍 CPU 已冻结后再捕获）
  ↓
S_SEND_CTRL  捕获addr/we/wdata（CPU已冻结，地址稳定）；发送CTRL字节
S_SEND_ADDR  发送ADDR字节
S_DATA0      发送WDAT[7:0]；FPGA开始输出rdata[7:0]（下一拍采样）
S_DATA1      发送WDAT[15:8]；采样 ext_in_i → rdata_buf[7:0]
S_DATA2      发送WDAT[23:16]；采样 ext_in_i → rdata_buf[15:8]
S_DATA3      发送WDAT[31:24]；采样 ext_in_i → rdata_buf[23:16]
S_LATCH      采样 ext_in_i → rdata_buf[31:24]；锁存到 s_rdata_o；
             置 transaction_done=1；→ S_IDLE（stall释放）
```

**关键机制：**

```verilog
wire any_cs  = s0_cs_i || s1_cs_i;
wire pending = any_cs && (state == S_IDLE) && !transaction_done;
assign stall_o = (state != S_IDLE) || pending;
// transaction_done：S_LATCH时置1，S_IDLE时清0（抑制一拍pending，
// 让M0 load/store完成后CPU有1拍空闲来advance并释放M0请求）
```

### 4.7 FPGA 侧桥接模块（`rtl/bridge/fpga_mem_bridge.v`）

单一模块，内含 ROM 和 RAM 两块存储体：

```verilog
module fpga_mem_bridge (
    input  wire       clk, rst,
    input  wire [7:0] ext_in_i,
    output reg  [7:0] ext_out_o
);
    reg [31:0] _rom [0:255];   // 256×32-bit
    reg [31:0] _ram [0:15];    //  16×32-bit
```

**6 状态 FSM：**

```
S_IDLE      ext_in_i[7]=1 → 捕获 mem_sel, we；→ S_RECV_ADDR
S_RECV_ADDR 捕获 addr；组合读存储体（用 ext_in_i 而非addr_r，避免1拍延迟）；
            输出 rdata[7:0]；→ S_DATA0
S_DATA0     输出 rdata[15:8]；捕获 wdata[7:0]
S_DATA1     输出 rdata[23:16]；捕获 wdata[15:8]
S_DATA2     输出 rdata[31:24]；捕获 wdata[23:16]
S_DATA3     输出 8'h0；捕获 wdata[31:24]；写操作→同步写存储体；→ S_IDLE
```

> **地址时序注意**：`S_RECV_ADDR` 中 addr 尚未写入 `addr_r`（下一拍才生效），需直接用 `ext_in_i` 作为地址进行组合读。

### 4.8 CPU hold 连接

```verilog
// tinyriscv_soc_top.v
wire mem_bridge_stall;
wire cpu_hold = mem_bridge_stall;
// tinyriscv 例化：
.rib_hold_flag_i(cpu_hold)
```

配合 ctrl.v 的 Hold_Pc→Hold_Id 修改，`cpu_hold` 在桥接事务期间冻结整条流水线（PC + if_id + id_ex）。

---

## 五、修改计划

### 5.1 需要新建的文件

| 文件 | 说明 |
|------|------|
| `rtl/bridge/rib_mem_bridge.v` | SoC 侧，8 状态机，继承 s0+s1 双接口，pending+transaction_done 机制 |
| `rtl/bridge/fpga_mem_bridge.v` | FPGA 侧，6 状态机，内含 ROM(256×32) + RAM(16×32) |

### 5.2 需要修改的文件（5 个）

#### `rtl/core/rib.v`（小改）

新增 `s0_cs_o`、`s1_cs_o` 端口；在 always@(*) 初始化中默认 0，访问对应 slave 时置 1：

```verilog
output reg s0_cs_o,   // 新增
output reg s1_cs_o,   // 新增
// always@(*) 初始化：
s0_cs_o = 1'b0; s1_cs_o = 1'b0;
// slave_0 分支中：s0_cs_o = 1'b1;
// slave_1 分支中：s1_cs_o = 1'b1;
```

#### `rtl/core/ctrl.v`（关键改动）

将 RIB hold 触发的 `Hold_Pc` 改为 `Hold_Id`，使桥接事务期间整条流水线冻结：

```verilog
// 修改前：
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Pc;
// 修改后：
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Id;
```

#### `rtl/soc/tinyriscv_soc_top.v`

- 新增 `s0_cs_o`、`s1_cs_o` 内部 wire 并连接 RIB
- 删除 `u_rom` / `u_ram` 例化
- 新增 `u_rib_mem_bridge` 例化（接管 s0+s1 双接口）
- 新增 `ext_mem_out[7:0]` / `ext_mem_in[7:0]` 顶层端口（共 16 根）
- `cpu_hold = mem_bridge_stall`，修改 CPU 的 `rib_hold_flag_i` 连接

#### `sim/compile_rtl.py`

```python
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/rib_mem_bridge.v')
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/fpga_mem_bridge.v')
```

#### `tb/tinyriscv_soc_tb.v`

- 新增 `wire [7:0] ext_mem_out, ext_mem_in`
- 例化 `fpga_mem_bridge u_fpga_mem`
- 修改 `$readmemh` 目标为 `u_fpga_mem._rom`
- SoC 顶层例化添加 `ext_mem_out` / `ext_mem_in` 端口连接

---

## 六、时序分析

### 6.1 事务时序（9 周期/次）

```
拍  SoC状态      ext_mem_out        FPGA状态     ext_mem_in
──────────────────────────────────────────────────────────────────
T   S_IDLE→CTRL  0（IDLE输出）      S_IDLE       0
T+1 S_SEND_CTRL  CTRL               S_IDLE→ADDR  0
T+2 S_SEND_ADDR  ADDR               S_RECV_ADDR  rdata[7:0]←组合读
T+3 S_DATA0      WDAT[7:0]          S_DATA0      rdata[15:8]
T+4 S_DATA1      WDAT[15:8]         S_DATA1      rdata[23:16]
T+5 S_DATA2      WDAT[23:16]        S_DATA2      rdata[31:24]
T+6 S_DATA3      WDAT[31:24]        S_DATA3      0（写操作此拍完成）
T+7 S_LATCH      0                  S_IDLE       0
    锁存rdata，transaction_done=1，stall=0
T+8 S_IDLE（空闲1拍，CPU advance）
```

- **stall 持续拍数**：T 到 T+7（共 8 拍，含 pending 的 T 拍和 S_LATCH 的 T+7 拍）
- **CPU 有效推进**：T+8（1 拍）
- **总周期**：9 拍/次内存访问

### 6.2 Hold_Id 正确性验证

| 阶段 | if_id 行为 | id_ex 行为 | 结论 |
|------|-----------|-----------|------|
| 桥接 8 拍（stall=1）| 冻结当前指令 ✓ | 冻结当前指令 ✓ | 流水线静止，无冲刷 |
| 空闲 1 拍（T+8）| 推进正确指令 ✓ | 推进正确指令 ✓ | EX 采样正确数据 |

写操作（M0 store）：EX 的 reg_we 和 s_rdata_o 在空闲拍写入寄存器；M0 请求随流水线推进自然释放，不需要 `rib_hold_flag_o` 参与 cpu_hold。

---

## 七、修改后容量影响

| 存储器 | 修改前 | 修改后 | 说明 |
|--------|--------|--------|------|
| ROM | 16KB（4096字）| **1KB（256字）** | 约 256 条 32-bit 指令；ISA 测试仅需 50~354 字 ✓ |
| RAM | 16KB（4096字）| **64B（16字）** | 极简程序使用，复杂程序需调大 DEPTH |

---

## 八、实施顺序

```
Step 1: 修改 rtl/core/rib.v       → 新增 s0_cs_o / s1_cs_o
Step 2: 修改 rtl/core/ctrl.v      → Hold_Pc 改为 Hold_Id
Step 3: 新建 rtl/bridge/rib_mem_bridge.v（8状态，SoC侧）
Step 4: 新建 rtl/bridge/fpga_mem_bridge.v（6状态，FPGA侧）
Step 5: 修改 rtl/soc/tinyriscv_soc_top.v
Step 6: 修改 sim/compile_rtl.py
Step 7: 修改 tb/tinyriscv_soc_tb.v
Step 8: 运行 test_all_isa.py 回归验证（目标：48/48 PASS）
```
