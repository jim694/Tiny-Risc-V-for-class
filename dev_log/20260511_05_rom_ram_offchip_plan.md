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

### 4.1 接口约束

处理器（SoC 芯片）与 FPGA 侧之间的物理接口限定为：

- **SoC → FPGA：8-bit 串行输出** `ext_XXX_out[7:0]`
- **FPGA → SoC：8-bit 串行输入** `ext_XXX_in[7:0]`

32-bit 数据字须分 4 字节串行传输，每次访问需要**6 个时钟周期**完成。这与原始组合读（0 延迟）不兼容，因此必须增加 **CPU 流水线暂停机制**。

### 4.2 总体结构

```
┌──────────────────────── SoC 芯片边界 ────────────────────────┐  ┌──── FPGA 侧 ──────────────────┐
│                                                              │  │                               │
│  RIB Slave 0 ──► rib_to_ext_bridge(ROM)                      │  │                               │
│                    [SoC侧状态机，6周期协议]  ext_rom_out[7:0] ├─►├─► fpga_ext_bridge(ROM)         │
│                    stall_o ─► OR门 ─► CPU  ext_rom_in[7:0]  ◄┤◄─┤─   [FPGA侧状态机]             │
│                                                              │  │    ──► _rom[0:255]            │
│  RIB Slave 1 ──► rib_to_ext_bridge(RAM)                      │  │                               │
│                    [SoC侧状态机，6周期协议]  ext_ram_out[7:0] ├─►├─► fpga_ext_bridge(RAM)         │
│                    stall_o ─► OR门 ─► CPU  ext_ram_in[7:0]  ◄┤◄─┤─   [FPGA侧状态机]             │
│                                                              │  │    ──► _ram[0:15]             │
└──────────────────────────────────────────────────────────────┘  └───────────────────────────────┘
```

**引脚对比（ROM + RAM 合计）：**

| 方案 | 引脚数 | 说明 |
|------|--------|------|
| 原计划（宽并行）| 144 根 | ROM 74 + RAM 70（地址+数据+控制）|
| 新方案（8-bit 串行）| 32 根 | ROM 16 + RAM 16（各 8in + 8out）|

### 4.3 帧协议（6 周期/次访问）

ROM 与 RAM 共用同一协议，每次 RIB 访问触发一帧：

```
周期   SoC → FPGA  ext_out[7:0]          FPGA → SoC  ext_in[7:0]
─────────────────────────────────────────────────────────────────
 0     CTRL = {cs, we, 6'b0}             8'h00（空）
 1     ADDR = word_addr[7:0]             8'h00（空；FPGA 此周期读取地址并访问存储器）
 2     WDAT[7:0]  （读操作时发 8'h00）   RDAT[7:0]
 3     WDAT[15:8]                        RDAT[15:8]
 4     WDAT[23:16]                       RDAT[23:16]
 5     WDAT[31:24]                       RDAT[31:24]  ← SoC 在此周期末锁存完整 rdata
```

- **读操作**：FPGA 在周期 1 末收到地址后立即（组合）读取存储器，从周期 2 开始串行发回 4 字节读数据
- **写操作**：FPGA 在周期 5 末收齐 4 字节写数据，同步写入存储器；ext_in 在写操作中全为 0
- **CPU 暂停**：SoC 桥接模块在周期 0 开始时即拉高 `stall_o`，周期 5 末（数据锁存后）释放

### 4.4 外部接口信号

| 信号 | 方向 | 位宽 | 说明 |
|------|------|------|------|
| `ext_rom_out[7:0]` | SoC → FPGA | 8 | ROM 串行输出帧（CTRL/ADDR/WDAT）|
| `ext_rom_in[7:0]` | FPGA → SoC | 8 | ROM 串行输入帧（RDAT）|
| `ext_ram_out[7:0]` | SoC → FPGA | 8 | RAM 串行输出帧 |
| `ext_ram_in[7:0]` | FPGA → SoC | 8 | RAM 串行输入帧 |

共 **4 组信号 × 8-bit = 32 根** 外部引脚（不含 clk/rst）。

### 4.5 SoC 侧桥接模块（`rtl/bridge/rib_to_ext_bridge.v`）

**接口：**

```verilog
module rib_to_ext_bridge #(
    parameter ADDR_WIDTH = 8           // ROM: 8-bit 字地址（256字）; RAM: 4-bit（16字）
)(
    input  wire        clk,
    input  wire        rst,
    // RIB 从设备接口
    input  wire [31:0] rib_addr_i,
    input  wire [31:0] rib_wdata_i,
    output reg  [31:0] rib_rdata_o,    // 锁存的读数据（6周期后有效）
    input  wire        rib_we_i,
    // 外部 8-bit 串行接口
    output reg  [7:0]  ext_out_o,      // 串行输出帧
    input  wire [7:0]  ext_in_i,       // 串行输入帧
    // CPU 暂停信号
    output wire        stall_o         // 高电平：事务进行中，流水线暂停
);
```

**内部状态机（7 状态）：**

```
S_IDLE    → 检测到新 RIB 访问 → S_SEND_CTRL
S_SEND_CTRL  周期0：输出 CTRL 字节；拉高 stall
S_SEND_ADDR  周期1：输出 ADDR 字节
S_DATA0      周期2：输出 WDAT[7:0]；采样 ext_in_i → rdata_buf[7:0]
S_DATA1      周期3：输出 WDAT[15:8]；采样 → rdata_buf[15:8]
S_DATA2      周期4：输出 WDAT[23:16]；采样 → rdata_buf[23:16]
S_DATA3      周期5：输出 WDAT[31:24]；采样 → rdata_buf[31:24]
             → 锁存 rdata_buf 到 rib_rdata_o；拉低 stall；→ S_IDLE
```

**新事务触发条件**：`{rib_addr_i, rib_we_i}` 与上一次事务不同（避免暂停期间重复触发）。

### 4.6 FPGA 侧桥接模块（`rtl/bridge/fpga_ext_bridge.v`）

ROM 与 RAM 可共用同一参数化模块（参数 `DEPTH` 和 `ADDR_WIDTH`）：

```verilog
module fpga_ext_bridge #(
    parameter DEPTH      = 256,        // ROM: 256; RAM: 16
    parameter ADDR_WIDTH = 8           // ROM: 8;   RAM: 4
)(
    input  wire       clk,
    input  wire       rst,
    // 8-bit 串行接口
    input  wire [7:0] ext_in_i,        // 接收 SoC 发来的帧
    output reg  [7:0] ext_out_o        // 发送读数据帧
);
    reg [31:0] _mem [0:DEPTH-1];       // 存储体
```

**内部状态机（6 状态）：**

```
S_IDLE       等待 CTRL 字节（ext_in_i[7]=cs 有效）
             解析 we = ext_in_i[6]
S_RECV_ADDR  接收地址字节，组合读存储器：rdata ← _mem[addr]
S_DATA0      发送 rdata[7:0]；接收 wdata[7:0]
S_DATA1      发送 rdata[15:8]；接收 wdata[15:8]
S_DATA2      发送 rdata[23:16]；接收 wdata[23:16]
S_DATA3      发送 rdata[31:24]；接收 wdata[31:24]
             如为写操作：同步写 _mem[addr] ← {wdat3,wdat2,wdat1,wdat0}
             → S_IDLE
```

### 4.7 CPU 暂停机制

原始连接：
```verilog
.rib_hold_flag_i(rib_hold_flag_o)   // 仅由 RIB 仲裁器驱动
```

修改后（在 `tinyriscv_soc_top.v` 中新增 OR 逻辑）：
```verilog
wire cpu_hold = rib_hold_flag_o | rom_bridge_stall | ram_bridge_stall;
// ...
.rib_hold_flag_i(cpu_hold)          // RIB 仲裁 + 桥接暂停共同驱动
```

此改动**不涉及 CPU 核或 RIB 总线内部**，仅在顶层添加一个 OR 门。

---

## 五、修改计划

### 5.1 需要新建的文件

| 文件 | 说明 |
|------|------|
| `rtl/bridge/rib_to_ext_bridge.v` | SoC 侧桥接：7 状态机，6 周期串行协议，输出 stall 信号 |
| `rtl/bridge/fpga_ext_bridge.v` | FPGA 侧桥接：6 状态机，ROM/RAM 参数化（含存储体）|

### 5.2 需要修改的文件

#### `rtl/soc/tinyriscv_soc_top.v`

**变更 1：** 替换 ROM/RAM 例化

```verilog
// 删除：
rom u_rom(...);
ram u_ram(...);

// 新增（ROM 桥，ADDR_WIDTH=8）：
rib_to_ext_bridge #(.ADDR_WIDTH(8)) u_rom_bridge (
    .clk(clk), .rst(rst),
    .rib_addr_i(s0_addr_o), .rib_wdata_i(s0_data_o),
    .rib_rdata_o(s0_data_i), .rib_we_i(s0_we_o),
    .ext_out_o(ext_rom_out), .ext_in_i(ext_rom_in),
    .stall_o(rom_bridge_stall)
);

// 新增（RAM 桥，ADDR_WIDTH=4）：
rib_to_ext_bridge #(.ADDR_WIDTH(4)) u_ram_bridge (
    .clk(clk), .rst(rst),
    .rib_addr_i(s1_addr_o), .rib_wdata_i(s1_data_o),
    .rib_rdata_o(s1_data_i), .rib_we_i(s1_we_o),
    .ext_out_o(ext_ram_out), .ext_in_i(ext_ram_in),
    .stall_o(ram_bridge_stall)
);
```

**变更 2：** 新增外部引脚（4 × 8-bit = 32 根）

```verilog
output wire [7:0] ext_rom_out,   // SoC → FPGA（ROM）
input  wire [7:0] ext_rom_in,    // FPGA → SoC（ROM）
output wire [7:0] ext_ram_out,   // SoC → FPGA（RAM）
input  wire [7:0] ext_ram_in,    // FPGA → SoC（RAM）
```

**变更 3：** 新增 CPU hold OR 逻辑

```verilog
wire rom_bridge_stall, ram_bridge_stall;
wire cpu_hold = rib_hold_flag_o | rom_bridge_stall | ram_bridge_stall;
// tinyriscv 例化中：.rib_hold_flag_i(cpu_hold)
```

#### `sim/compile_rtl.py`

```python
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/rib_to_ext_bridge.v')
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/fpga_ext_bridge.v')
```

#### `tb/tinyriscv_soc_tb.v`

**变更 1：** 新增连线与 FPGA 侧模块例化

```verilog
wire [7:0] ext_rom_out, ext_rom_in;
wire [7:0] ext_ram_out, ext_ram_in;

// FPGA 侧 ROM（256×32-bit）
fpga_ext_bridge #(.DEPTH(256), .ADDR_WIDTH(8)) u_fpga_rom (
    .clk(clk), .rst(rst),
    .ext_in_i(ext_rom_out),    // SoC 输出 → FPGA 输入
    .ext_out_o(ext_rom_in)     // FPGA 输出 → SoC 输入
);

// FPGA 侧 RAM（16×32-bit）
fpga_ext_bridge #(.DEPTH(16), .ADDR_WIDTH(4)) u_fpga_ram (
    .clk(clk), .rst(rst),
    .ext_in_i(ext_ram_out),
    .ext_out_o(ext_ram_in)
);
```

**变更 2：** `$readmemh` 目标路径

```verilog
// 修改前：$readmemh("inst.data", tinyriscv_soc_top_0.u_rom._rom);
// 修改后：
$readmemh("inst.data", u_fpga_rom._mem);
```

**变更 3：** SoC 顶层例化添加 4 个外部接口端口。

---

## 六、时序影响分析

| 项目 | 原始（片内）| 新方案（8-bit 串行）|
|------|-----------|-------------------|
| 读延迟 | 0 周期（组合）| **6 周期**（状态机串行）|
| 写延迟 | 1 周期（同步写）| **6 周期**（串行后同步写）|
| CPU 暂停 | 无 | 每次访存暂停 **6 周期** |
| 外部引脚数 | — | **32 根**（4×8-bit）|
| 时序复杂度 | 简单组合 | SoC+FPGA 两侧各需状态机 |

**性能影响估算：** 原 CPU 取指+执行各 1 周期，新方案每次取指或访存增加 6 周期暂停。对 ISA 仿真测试结果（PASS/FAIL）无影响，但仿真时长增加约 3~6 倍。

---

## 七、修改后容量影响

| 存储器 | 修改前 | 修改后 | 说明 |
|--------|--------|--------|------|
| ROM | 16KB（4096字）| 1KB（256字）| 约 256 条 32-bit 指令 |
| RAM | 16KB（4096字）| 64B（16字）| 极简程序专用 |

> **注意：** ROM 256字对 ISA 仿真测试**足够**。RAM 16字（64B）极小，若测试程序有较深的栈操作，需适当增大 DEPTH 参数。

---

## 八、实施顺序

```
Step 1: 新建 rtl/bridge/ 目录，实现两个桥接模块
        ├── rib_to_ext_bridge.v（SoC侧：7状态机 + stall 输出）
        └── fpga_ext_bridge.v（FPGA侧：6状态机 + 参数化存储体）

Step 2: 修改 rtl/soc/tinyriscv_soc_top.v
        ├── 删除 u_rom / u_ram 例化
        ├── 新增 u_rom_bridge / u_ram_bridge 例化（rib_to_ext_bridge）
        ├── 新增 4 个 8-bit 外部接口引脚
        └── 新增 cpu_hold OR 逻辑，修改 CPU hold 连接

Step 3: 修改 tb/tinyriscv_soc_tb.v
        ├── 新增 fpga_ext_bridge（ROM/RAM）例化
        ├── 连接 4 组 8-bit 接口信号
        └── 修改 $readmemh 目标路径为 u_fpga_rom._mem

Step 4: 修改 sim/compile_rtl.py
        └── 新增两个 bridge 文件的编译路径

Step 5: 运行 test_all_isa.py 回归验证（48/48 PASS 为目标）
```
