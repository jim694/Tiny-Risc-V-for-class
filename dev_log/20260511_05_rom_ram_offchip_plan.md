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

### 4.1 总体结构

```
┌─────────────────── SoC 芯片边界 ─────────────┐   ┌─── FPGA 侧 ───────────────────┐
│                                              │   │                               │
│  RIB 总线                                    │   │                               │
│  Slave 0 (s0_*)──► rib_to_ext_bridge_rom ───┼───┼──► fpga_ext_rom  ──► _rom[255:0]│
│                     [SoC侧桥接模块]           │   │    [FPGA侧桥接]                │
│                                              │   │                               │
│  Slave 1 (s1_*)──► rib_to_ext_bridge_ram ───┼───┼──► fpga_ext_ram  ──► _ram[15:0] │
│                     [SoC侧桥接模块]           │   │    [FPGA侧桥接]                │
│                                              │   │                               │
└─────────────────────────────────────────────┘   └───────────────────────────────┘
         片内（RTL 综合到处理器核）                        片外（FPGA Block RAM 或 SRAM）
```

### 4.2 外部接口信号定义

**ROM 外部接口（9 根信号线）：**

| 信号 | 方向（SoC→FPGA） | 位宽 | 说明 |
|------|----------------|------|------|
| `ext_rom_cs` | → | 1 | 片选（高有效）|
| `ext_rom_we` | → | 1 | 写使能（高有效）|
| `ext_rom_addr` | → | 8 | 字地址（对应 addr[9:2]，256 个字）|
| `ext_rom_wdata` | → | 32 | 写数据 |
| `ext_rom_rdata` | ← | 32 | 读数据 |

**RAM 外部接口（9 根信号线）：**

| 信号 | 方向（SoC→FPGA） | 位宽 | 说明 |
|------|----------------|------|------|
| `ext_ram_cs` | → | 1 | 片选（高有效）|
| `ext_ram_we` | → | 1 | 写使能（高有效）|
| `ext_ram_addr` | → | 4 | 字地址（对应 addr[5:2]，16 个字）|
| `ext_ram_wdata` | → | 32 | 写数据 |
| `ext_ram_rdata` | ← | 32 | 读数据 |

### 4.3 SoC 侧桥接模块（`rtl/bridge/rib_to_ext_bridge.v`）

ROM 和 RAM 可共用同一参数化模块，通过参数 `ADDR_WIDTH` 区分地址位宽（ROM=8，RAM=4）。

**接口定义：**

```verilog
module rib_to_ext_bridge #(
    parameter ADDR_WIDTH = 8          // ROM: 8, RAM: 4
)(
    // RIB 从设备接口（输入）
    input  wire [31:0] rib_addr_i,    // RIB 总线字节地址
    input  wire [31:0] rib_wdata_i,   // RIB 总线写数据
    output wire [31:0] rib_rdata_o,   // RIB 总线读数据
    input  wire        rib_we_i,      // RIB 总线写使能

    // 外部存储接口（输出/输入）
    output wire [ADDR_WIDTH-1:0] ext_addr_o,   // 字地址
    output wire [31:0]           ext_wdata_o,  // 写数据透传
    input  wire [31:0]           ext_rdata_i,  // 读数据透传
    output wire                  ext_we_o,     // 写使能透传
    output wire                  ext_cs_o      // 片选（非复位时有效）
);
```

**逻辑说明：**

- 全部为**纯组合逻辑**（无时钟），维持 RIB 总线零延迟读的要求
- 地址转换：`ext_addr_o = rib_addr_i[ADDR_WIDTH+1:2]`（截取字地址有效位）
- 读数据直通：`rib_rdata_o = ext_rdata_i`
- 写数据/控制直通：`ext_wdata_o = rib_wdata_i`，`ext_we_o = rib_we_i`
- 片选逻辑：`ext_cs_o = 1'b1`（桥接模块不需要管复位，由 FPGA 侧存储器内部处理）

### 4.4 FPGA 侧桥接模块

**ROM（`rtl/bridge/fpga_ext_rom.v`）：**

```verilog
module fpga_ext_rom (
    input  wire        clk,
    input  wire        rst,
    input  wire        ext_cs_i,
    input  wire        ext_we_i,
    input  wire [7:0]  ext_addr_i,     // 8-bit 字地址，寻址 256 个字
    input  wire [31:0] ext_wdata_i,
    output reg  [31:0] ext_rdata_o
);
    reg [31:0] _rom [0:255];           // 256 × 32-bit = 1KB

    // 写：同步
    always @ (posedge clk) begin
        if (ext_cs_i && ext_we_i)
            _rom[ext_addr_i] <= ext_wdata_i;
    end

    // 读：组合
    always @ (*) begin
        if (rst == `RstEnable || !ext_cs_i)
            ext_rdata_o = 32'h0;
        else
            ext_rdata_o = _rom[ext_addr_i];
    end
endmodule
```

**RAM（`rtl/bridge/fpga_ext_ram.v`）：**

```verilog
module fpga_ext_ram (
    input  wire        clk,
    input  wire        rst,
    input  wire        ext_cs_i,
    input  wire        ext_we_i,
    input  wire [3:0]  ext_addr_i,     // 4-bit 字地址，寻址 16 个字
    input  wire [31:0] ext_wdata_i,
    output reg  [31:0] ext_rdata_o
);
    reg [31:0] _ram [0:15];            // 16 × 32-bit = 64B

    always @ (posedge clk) begin
        if (ext_cs_i && ext_we_i)
            _ram[ext_addr_i] <= ext_wdata_i;
    end
    always @ (*) begin
        if (rst == `RstEnable || !ext_cs_i)
            ext_rdata_o = 32'h0;
        else
            ext_rdata_o = _ram[ext_addr_i];
    end
endmodule
```

---

## 五、修改计划

### 5.1 需要新建的文件

| 文件 | 说明 |
|------|------|
| `rtl/bridge/rib_to_ext_bridge.v` | SoC 侧桥接模块（参数化，ROM/RAM 共用）|
| `rtl/bridge/fpga_ext_rom.v` | FPGA 侧 ROM（256×32-bit）|
| `rtl/bridge/fpga_ext_ram.v` | FPGA 侧 RAM（16×32-bit）|

### 5.2 需要修改的文件

#### `rtl/soc/tinyriscv_soc_top.v`

**变更 1：** 删除 `u_rom` 和 `u_ram` 例化，替换为 `rib_to_ext_bridge` 例化：

```verilog
// 删除：
rom u_rom ( .clk, .rst, .we_i(s0_we_o), .addr_i(s0_addr_o), ... );
ram u_ram ( .clk, .rst, .we_i(s1_we_o), .addr_i(s1_addr_o), ... );

// 新增：
rib_to_ext_bridge #(.ADDR_WIDTH(8)) u_rom_bridge (
    .rib_addr_i(s0_addr_o), .rib_wdata_i(s0_data_o),
    .rib_rdata_o(s0_data_i), .rib_we_i(s0_we_o),
    .ext_addr_o(ext_rom_addr), .ext_wdata_o(ext_rom_wdata),
    .ext_rdata_i(ext_rom_rdata), .ext_we_o(ext_rom_we),
    .ext_cs_o(ext_rom_cs)
);

rib_to_ext_bridge #(.ADDR_WIDTH(4)) u_ram_bridge (
    .rib_addr_i(s1_addr_o), .rib_wdata_i(s1_data_o),
    .rib_rdata_o(s1_data_i), .rib_we_i(s1_we_o),
    .ext_addr_o(ext_ram_addr), .ext_wdata_o(ext_ram_wdata),
    .ext_rdata_i(ext_ram_rdata), .ext_we_o(ext_ram_we),
    .ext_cs_o(ext_ram_cs)
);
```

**变更 2：** 顶层新增对外引脚（共 18 根）：

```verilog
// ROM 外部接口
output wire        ext_rom_cs,
output wire        ext_rom_we,
output wire [7:0]  ext_rom_addr,
output wire [31:0] ext_rom_wdata,
input  wire [31:0] ext_rom_rdata,
// RAM 外部接口
output wire        ext_ram_cs,
output wire        ext_ram_we,
output wire [3:0]  ext_ram_addr,
output wire [31:0] ext_ram_wdata,
input  wire [31:0] ext_ram_rdata,
```

#### `sim/compile_rtl.py`

新增三个文件的编译路径：

```python
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/rib_to_ext_bridge.v')
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/fpga_ext_rom.v')
iverilog_cmd.append(rtl_dir + r'/rtl/bridge/fpga_ext_ram.v')
```

#### `tb/tinyriscv_soc_tb.v`

**变更 1：** 在 testbench 中例化 FPGA 侧存储模块并连接到 SoC 顶层外部接口：

```verilog
// 外部接口连线
wire        ext_rom_cs, ext_rom_we;
wire [7:0]  ext_rom_addr;
wire [31:0] ext_rom_wdata, ext_rom_rdata;
wire        ext_ram_cs, ext_ram_we;
wire [3:0]  ext_ram_addr;
wire [31:0] ext_ram_wdata, ext_ram_rdata;

// FPGA 侧 ROM 例化
fpga_ext_rom u_fpga_rom (
    .clk(clk), .rst(rst),
    .ext_cs_i(ext_rom_cs), .ext_we_i(ext_rom_we),
    .ext_addr_i(ext_rom_addr), .ext_wdata_i(ext_rom_wdata),
    .ext_rdata_o(ext_rom_rdata)
);

// FPGA 侧 RAM 例化
fpga_ext_ram u_fpga_ram (
    .clk(clk), .rst(rst),
    .ext_cs_i(ext_ram_cs), .ext_we_i(ext_ram_we),
    .ext_addr_i(ext_ram_addr), .ext_wdata_i(ext_ram_wdata),
    .ext_rdata_o(ext_ram_rdata)
);
```

**变更 2：** `$readmemh` 目标路径从 SoC 内部 ROM 改为 FPGA 侧 ROM：

```verilog
// 修改前
$readmemh("inst.data", tinyriscv_soc_top_0.u_rom._rom);

// 修改后
$readmemh("inst.data", u_fpga_rom._rom);
```

**变更 3：** SoC 顶层例化中连接新增的外部接口端口。

#### `rtl/core/defines.v`（可选）

`RomNum` 和 `MemNum` 不再被 rom.v/ram.v 直接引用（它们已被移除），可以删除或保留为注释。

---

## 六、时序兼容性分析

当前 RIB 总线对从设备的时序要求：

```
Master 发出 addr_i → 同周期内从设备给出 data_o
（组合读，无 ACK 握手）
```

新架构中，SoC 侧桥接模块（`rib_to_ext_bridge`）为纯组合逻辑，FPGA 侧存储模块保持组合读（`always @(*)`），整体链路：

```
RIB addr → rib_to_ext_bridge（组合）→ ext_rom_addr → fpga_ext_rom（组合读）→ ext_rom_rdata → rib_rdata_o
```

**全程组合逻辑，零额外延迟，与原始片内 ROM/RAM 时序完全兼容，无需修改 CPU 核或 RIB 仲裁逻辑。**

---

## 七、修改后容量影响

| 存储器 | 修改前 | 修改后 | 说明 |
|--------|--------|--------|------|
| ROM | 16KB（4096字）| 1KB（256字）| 可容纳约 256 条 32-bit 指令 |
| RAM | 16KB（4096字）| 64B（16字）| 仅供极简程序使用 |

> **注意：** 修改后的 ROM（256字）对仿真 ISA 测试而言**足够**——每条测试程序通常不超过 200 条指令。RAM（16字=64B）极小，仅适合无栈或极浅栈程序；若测试程序有大量 store/load 操作，需适当增大 RAM 深度。

---

## 八、实施顺序

```
Step 1: 新建 rtl/bridge/ 目录，实现三个模块
        ├── rib_to_ext_bridge.v（参数化桥接，纯组合）
        ├── fpga_ext_rom.v（256×32-bit，组合读+同步写）
        └── fpga_ext_ram.v（16×32-bit，组合读+同步写）

Step 2: 修改 rtl/soc/tinyriscv_soc_top.v
        ├── 删除 u_rom / u_ram 例化
        ├── 新增 u_rom_bridge / u_ram_bridge 例化
        └── 新增 10 个对外 ROM/RAM 引脚

Step 3: 修改 tb/tinyriscv_soc_tb.v
        ├── 新增 fpga_ext_rom / fpga_ext_ram 例化
        ├── 连接外部接口信号
        └── 修改 $readmemh 目标路径

Step 4: 修改 sim/compile_rtl.py
        └── 新增三个 bridge 文件的编译路径

Step 5: 运行 test_all_isa.py 回归验证（48/48 PASS 为目标）
```
