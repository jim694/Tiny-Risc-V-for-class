# RT 自定义指令设计文档（Read Temperature）

**日期：** 2026-05-14  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）  
**状态：** 设计阶段，待实现

---

## 一、功能描述

新增自定义指令 **RT**（Read Temperature）。CPU 译码到该指令时，通过 SoC 内置 I2C 控制器读取 FPGA 开发板上的温度传感器 **LM75** 的温度寄存器（Pointer = 0x00），从 16 位原始读数中提取 `[14:7]`（共 8 位，精度 0.5°C），零扩展后写入目标寄存器 `x[rd]`。流水线在整个 I2C 事务期间持续暂停，完成后恢复执行。

### 温度数据映射

LM75 温度寄存器为 16 位，I2C 先发 MSB 字节（上字节），再发 LSB 字节（下字节）：

| 位域 | 含义 |
|------|------|
| D15 | 符号位（正温度为 0） |
| D14~D8 | 整数部分（64, 32, 16, 8, 4, 2, 1 °C） |
| D7 | 小数位（0.5°C） |
| D6~D0 | 无关位 |

指令要求提取 `[14:7]`：
- 来自 I2C 第 1 字节（MSB）的 `[6:0]`：整数摄氏度（最大 127°C）
- 来自 I2C 第 2 字节（LSB）的 `[7]`：0.5°C 精度位

结果存入 rd：`rd = {24'h0, MSB[6:0], LSB[7]}`

---

## 二、指令编码

### 2.1 与 sID 的关系

RT 指令与已实现的 sID 指令**共享 opcode `0101111`**，由 `funct3` 区分：

| 指令 | opcode | funct3 | 机器码（典型） |
|------|--------|--------|--------------|
| sID  | 0101111 | 000    | `0x0000_002F` |
| RT   | 0101111 | 001    | `imm[11:0] ⌚ rs1 ⌚ 001 ⌚ rd ⌚ 0101111` |

### 2.2 字段定义

```
 31      20 19  15 14  12 11   7 6      0
┌──────────┬──────┬──────┬──────┬────────┐
│ i2c_addr │rs1=0 │ 001  │  rd  │0101111 │
└──────────┴──────┴──────┴──────┴────────┘
```

| 字段 | 位域 | 说明 |
|------|------|------|
| opcode | [6:0] | `7'b0101111` |
| rd | [11:7] | 目标寄存器（写入温度读数） |
| funct3 | [14:12] | `3'b001`（区分 sID 的 `3'b000`） |
| rs1 | [19:15] | 不使用，置 0 |
| imm[11:0] | [31:20] | 可选：LM75 的 7 位 I2C 地址（`imm[6:0]`），0 时使用默认地址 `7'h48` |

**C 内联汇编写法（温度存入 a0，使用默认地址 0x48）：**

```c
int temp;
asm volatile(".insn i 0x2f, 1, %0, x0, 0" : "=r"(temp));
// temp 低 8 位即温度（单位 0.5°C）
// 例：temp=0x32=50 → 实际温度 25.0°C
```

---

## 三、现有 I2C 控制器分析

### 3.1 寄存器映射（已实现于 `rtl/perips/i2c.v`）

| 地址 | 寄存器 | 位域说明 |
|------|--------|---------|
| `0x7001_0000` | CTRL | [6:0]=从机7位地址; [7]=R/W(1=读); [8]=START触发(写); [9]=BUSY(读) |
| `0x7002_0000` | WDATA | [7:0]=要写入从机的数据 |
| `0x7003_0000` | RDATA | [7:0]=从从机读到的数据（只读） |

**时序参数**：50MHz 系统时钟，100kHz I2C（CLK_DIV=250，即 250 个系统时钟/半个 SCL 周期）

### 3.2 关键约束：单字节读限制

**当前 i2c.v 每次事务只能读 1 字节**（读完后立即发 NACK+STOP）。而 LM75 温度寄存器需要连续读取 2 字节（MSB 后 ACK，LSB 后 NACK+STOP）。

**必须修改 i2c.v** 以支持 2 字节读模式，否则无法获取 D7（0.5°C）精度位。

### 3.3 单次 I2C 事务耗时估算

每次完整 I2C 事务（START + 8bit addr + ACK + 8bit data + ACK/NACK + STOP）：
- = 约 (2 + 8×2 + 2 + 8×2 + 2 + 2) 个半周期 × 250 系统时钟
- = 40 × 250 = **10,000 系统时钟 = 200 µs**

RT 指令需要 2 次事务（写指针 + 读2字节）：约 **~20,000 周期（400 µs）**。

---

## 四、LM75 I2C 读取流程

### 4.1 LM75 默认参数（FPGA 开发板）

- I2C 地址：`7'h48`（A2=A1=A0=0，全部接 GND 时）
- 温度寄存器 Pointer：`0x00`（上电默认已指向温度寄存器）
- 数据格式：大端，先发 MSB

### 4.2 完整 I2C 时序（2字节读）

```
Phase 1：写操作（设置 Pointer 寄存器为 0x00）
  START → 0x90（0x48写地址）→ ACK → 0x00（Pointer）→ ACK → STOP

Phase 2：读操作（读温度寄存器，2字节）
  START → 0x91（0x48读地址）→ ACK → MSB字节 → ACK → LSB字节 → NACK → STOP
```

实际上若上电后 LM75 Pointer 已经是 0x00，Phase 1 可省略。但为确保正确性，仍建议执行。

---

## 五、实现方案

### 5.1 修改 i2c.v：增加 2 字节读模式

在 CTRL 寄存器增加 bit[10] = `TWO_BYTE`：
- CTRL 写入时若 bit[10]=1，进入 2 字节读模式
- 读取第 1 字节后发 ACK（而非 NACK），继续接收第 2 字节，再发 NACK+STOP
- 新增寄存器 RDATA_MSB（可重命名为 RDATA_B1）存第 1 字节，原 RDATA 存第 2 字节

**寄存器映射扩展：**

| 地址 | 寄存器 | 说明 |
|------|--------|------|
| `0x7001_0000` | CTRL | 新增 bit[10]: TWO_BYTE 模式 |
| `0x7002_0000` | WDATA | 同前 |
| `0x7003_0000` | RDATA（B2/LSB） | 1字节模式：读数据；2字节模式：第2字节 |
| `0x7004_0000` | RDATA_B1（MSB） | 2字节模式：第1字节（新增） |

**i2c.v 状态机修改**：在 ST_RDATA 接收完 8 bit 后判断 `ctrl_two_byte`：
```
if (ctrl_two_byte && !second_byte) begin
    // 发 ACK（sda_out=0），接收第 2 字节
    second_byte <= 1'b1;
    rdata_b1 <= {shift_r[6:0], sda_in};  // 保存 MSB
    sda_out_r <= 1'b0;   // ACK
    // 进入 RACK 状态（2半周期），然后回到 ST_RDATA
end else begin
    // 发 NACK，进入 ST_STOP（原有逻辑）
end
```

### 5.2 id.v 修改：RT 指令译码

在 INST_SID opcode 的 case 分支内，用 `funct3`（`inst_i[14:12]`）区分 sID 和 RT：

```verilog
`INST_SID: begin
    if (inst_i[14:12] == 3'b000) begin
        // sID：原有逻辑，不读写寄存器
        reg_we_o    = `WriteDisable;
        reg_waddr_o = `ZeroReg;
        reg1_raddr_o = `ZeroReg;
        reg2_raddr_o = `ZeroReg;
    end else begin
        // RT（funct3=001）：rd 需要写回
        reg_we_o    = `WriteEnable;
        reg_waddr_o = inst_i[11:7];   // rd
        reg1_raddr_o = `ZeroReg;
        reg2_raddr_o = `ZeroReg;
    end
end
```

> **注意**：RT 需要 `reg_we_o=WriteEnable`，以便 EX 阶段最终将温度数据写回 rd。

### 5.3 ex.v 修改：RT 时序状态机

#### 5.3.1 新增 define

在 `defines.v` 中（RT 与 sID 共享 opcode，不需要新 opcode define，用 funct3 区分）：
```verilog
`define FUNCT3_SID  3'b000
`define FUNCT3_RT   3'b001
```

#### 5.3.2 RT 状态机寄存器

```verilog
// RT 状态机
localparam RT_IDLE     = 4'd0;
localparam RT_WR_WDATA = 4'd1;   // 写 WDATA=0x00（Pointer）
localparam RT_WR_CTRL_W= 4'd2;   // 写 CTRL 触发写事务（设置 Pointer）
localparam RT_POLL_W   = 4'd3;   // 发起总线读 CTRL，采样 BUSY
localparam RT_CHK_W    = 4'd4;   // 检查 BUSY；若0，进入读事务
localparam RT_WR_CTRL_R= 4'd5;   // 写 CTRL 触发2字节读事务
localparam RT_POLL_R   = 4'd6;   // 发起总线读 CTRL，采样 BUSY
localparam RT_CHK_R    = 4'd7;   // 检查 BUSY；若0，读温度数据
localparam RT_RD_B1    = 4'd8;   // 发起总线读 RDATA_B1（MSB）
localparam RT_LATCH_B1 = 4'd9;   // 锁存 MSB
localparam RT_RD_B2    = 4'd10;  // 发起总线读 RDATA_B2（LSB）
localparam RT_LATCH_B2 = 4'd11;  // 锁存 LSB，计算结果，rt_done=1

reg [3:0] rt_state;
reg       rt_active, rt_done;
reg [4:0] rt_rd_addr;      // 锁存 rd（opcode 被 flush 后不变）
reg [7:0] rt_msb, rt_lsb; // 温度 MSB/LSB
reg [7:0] rt_i2c_dev;     // LM75 I2C 地址（默认 0x48）
```

#### 5.3.3 状态机触发与 hold 覆盖（同 sID 模式）

组合块 case(opcode) 外，与 sID 同理，用 `rt_active` 覆盖 hold：

```verilog
// case(opcode) 之后
if (rt_active) begin
    hold_flag = `HoldEnable;
    reg_we    = `WriteDisable;   // 完成前不写回
    jump_flag = `JumpDisable;
    jump_addr = `ZeroWord;
    reg_wdata = `ZeroWord;
    // 总线请求由时序块驱动（见下）
end

if (rt_done) begin
    // 最后一拍：写回温度到 rd
    hold_flag   = `HoldDisable;
    reg_we      = `WriteEnable;
    reg_waddr   = rt_rd_addr;
    reg_wdata   = {24'h0, rt_msb[6:0], rt_lsb[7]};  // bits[14:7]
end
```

#### 5.3.4 状态机时序逻辑（主要结构）

```verilog
always @ (posedge clk) begin
    if (rst == `RstEnable) begin
        rt_state <= RT_IDLE; rt_active <= 0; rt_done <= 0;
        ...
    end else begin
        // 触发：首拍检测到 INST_SID + funct3==001
        if (opcode == `INST_SID && inst_i[14:12] == 3'b001
                && !rt_active && !rt_done) begin
            rt_active   <= 1'b1;
            rt_rd_addr  <= reg_waddr_i;  // 锁存 rd
            rt_i2c_dev  <= (inst_i[31:25] == 7'h0) ? 7'h48 : inst_i[26:20]; // imm[6:0]
            rt_state    <= RT_WR_WDATA;
        end

        if (rt_active) begin
            case (rt_state)
                RT_WR_WDATA: begin
                    // 驱动总线：WDATA=0x00（通过组合块，当前周期有效）
                    rt_state <= RT_WR_CTRL_W;
                end
                RT_WR_CTRL_W: begin
                    // 驱动总线：CTRL = {23'h0, 1'b1(START), 1'b0(W), rt_i2c_dev}
                    rt_state <= RT_POLL_W;
                end
                RT_POLL_W: begin
                    // 驱动总线：读 CTRL（mem_req=REQ, we=0, addr=CTRL）
                    rt_state <= RT_CHK_W;
                end
                RT_CHK_W: begin
                    if (mem_rdata_i[9] == 1'b0)   // BUSY=0，写事务完成
                        rt_state <= RT_WR_CTRL_R;
                    else
                        rt_state <= RT_POLL_W;  // 继续等
                end
                RT_WR_CTRL_R: begin
                    // CTRL = {22'h0, 1'b1(TWO_BYTE), 1'b1(START), 1'b1(R), rt_i2c_dev}
                    rt_state <= RT_POLL_R;
                end
                RT_POLL_R: begin
                    // 读 CTRL 检查 BUSY
                    rt_state <= RT_CHK_R;
                end
                RT_CHK_R: begin
                    if (mem_rdata_i[9] == 1'b0)
                        rt_state <= RT_RD_B1;
                    else
                        rt_state <= RT_POLL_R;
                end
                RT_RD_B1: begin
                    // 读 RDATA_B1 (0x7004_0000)
                    rt_state <= RT_LATCH_B1;
                end
                RT_LATCH_B1: begin
                    rt_msb   <= mem_rdata_i[7:0];
                    rt_state <= RT_RD_B2;
                end
                RT_RD_B2: begin
                    // 读 RDATA_B2 (0x7003_0000)
                    rt_state <= RT_LATCH_B2;
                end
                RT_LATCH_B2: begin
                    rt_lsb   <= mem_rdata_i[7:0];
                    rt_active <= 1'b0;
                    rt_done   <= 1'b1;   // 触发写回
                    rt_state  <= RT_IDLE;
                end
            endcase
        end

        if (!rt_active && rt_done) begin
            rt_done <= 1'b0;  // 写回后下一拍清零
        end
    end
end
```

> **总线驱动**：组合逻辑块中，根据 `rt_active` 和 `rt_state` 驱动 `mem_req`, `mem_we`, `mem_waddr_o`, `mem_wdata_o`, `mem_raddr_o`。每个状态对应一组总线信号。

---

## 六、关键技术问题

### 6.1 Hold 机制（与 sID 相同问题）

Hold_Id 会 flush id_ex，使 EX 下一拍 opcode 变为 NOP。解决方案与 sID 完全相同：在 case(opcode) 外部使用 `rt_active` 寄存器持续覆盖 hold，不依赖 opcode。

### 6.2 rd 地址的保存

opcode 被 flush 后 `reg_waddr_i` 变为 0（NOP）。必须在触发时（`rt_active <= 1`的同一拍）锁存 `reg_waddr_i` 到 `rt_rd_addr`，后续写回使用 `rt_rd_addr`。

### 6.3 总线驱动的状态依赖

RT 状态机与 sID 不同之处：RT 需要在不同状态驱动不同地址（CTRL/WDATA/RDATA_B1/RDATA_B2），且有读操作（`mem_we=WriteDisable`）。各状态对应的组合逻辑需在 `if (rt_active)` 块内按 `rt_state` 分支驱动总线。

### 6.4 BUSY 轮询的延迟

I2C 控制器的 RDATA 在 RIB 总线读取时为组合逻辑输出（无需经过 fpga_mem_bridge），因此 1 个系统时钟即可得到响应。每次 RT_POLL → RT_CHK 共 2 个系统时钟（发地址 → 下拍读数据）。

### 6.5 sID 与 RT 状态机的并存

两者均在 EX 中，通过各自的 `sid_active` / `rt_active` 标志独立运行，互不干扰（同一时刻只会执行一条自定义指令）。case(opcode) 之后的覆盖块需依次检查两个 active 标志：
```verilog
if (sid_active) begin ... end
if (rt_active)  begin ... end   // rt_done 写回在此也可处理
```

---

## 七、需修改的文件

| 文件 | 改动内容 |
|------|---------|
| `rtl/core/defines.v` | 新增 `` `define FUNCT3_RT 3'b001 `` |
| `rtl/perips/i2c.v` | 增加 2字节读模式（CTRL bit[10]）；新增 RDATA_B1 寄存器（addr 0x7004_0000）；状态机 ST_RDATA 扩展 ACK+第2字节接收 |
| `rtl/core/id.v` | INST_SID case 内按 funct3 分支：funct3=001 时 reg_we=Enable，reg_waddr=rd |
| `rtl/core/ex.v` | 新增 RT 状态机寄存器；新增 RT 触发逻辑；case 外 rt_active 覆盖；总线驱动按 rt_state 分支 |

---

## 八、验证方案

测试用例已提供：`tests/Extend_Inst_Example/Temp/Temp.data`

程序逻辑（`Temp.c`）：使能 UART TX → 调用 RT 指令读温度（结果存 a0）→ 将温度值写入 UART TX（0x3000_000C）→ 程序返回，x26=1。  
**x27 不被设置（保持 0）**：testbench 会显示 TEST_FAIL，这是预期行为——此测试通过 UART TX 写入值或波形验证，不靠 x27。

### 8.1 Phase A：流水线完成性验证

**前提**：testbench 需为 `io_sda` 加上拉，避免悬空产生 X 态。

```verilog
// tb/tinyriscv_soc_tb.v：例化 SoC 时补充 I2C 引脚
wire io_scl_w;
wire io_sda_w;
pullup u_sda_pu(io_sda_w);   // 模拟 I2C 外部上拉电阻

tinyriscv_soc_top tinyriscv_soc_top_0(
    ...
    .io_scl(io_scl_w),
    .io_sda(io_sda_w)
);
```

无 I2C slave 时，i2c.v 在地址 ACK 阶段收到高电平（NACK）→ 直接进 STOP → `ctrl_busy=0`，RT 状态机正常退出，温度值为 0。

**预期结果：**
- x26 = 1（程序正常完成）
- 仿真不超时（RT 状态机有限步完成，约 400µs 内）
- UART TX 寄存器被写入 0x0（无 slave 时）
- 波形可见 `io_scl` 上出现两次 I2C 时钟波形

运行方法：
```bash
cd sim
python sim_basic_example.py ../tests/Extend_Inst_Example/Temp/Temp.data
```

### 8.2 Phase B：温度数值正确性验证（force 注入）

无需 I2C slave stub，在 testbench initial 块中用层次访问强制注入温度数据：

目标温度 **25°C**：上字节 MSB = `0x19`，下字节 LSB = `0x00`  
→ bits[14:7] = `{0x19[6:0], 0x00[7]}` = `{001_1001, 0}` = `0x32` = 50 → 25.0°C

```verilog
// testbench 中增加 force 块（RT 执行完毕后 I2C 数据已稳定，提前强制注入）
initial begin
    // 等 I2C 控制器完成最后一次读事务（BUSY 从 1 变 0）
    @(negedge tinyriscv_soc_top_0.u_i2c.ctrl_busy);
    force tinyriscv_soc_top_0.u_i2c.rdata_b1 = 8'h19;  // MSB：25°C 上字节
    force tinyriscv_soc_top_0.u_i2c.rdata_r  = 8'h00;  // LSB：25°C 下字节
    #20;
    release tinyriscv_soc_top_0.u_i2c.rdata_b1;
    release tinyriscv_soc_top_0.u_i2c.rdata_r;
end
```

**预期结果：** UART TX 寄存器写入值 = `0x32`（通过波形 `mem_wdata_o` 或 `$monitor` 确认）

### 8.3 回归测试

RT 指令实现完成后跑 `sim/test_basic_example.py`，确认 24/24 基本指令全部 PASS。

### 8.4 上板验证

通过 UART 下载 `Temp.data` 至 FPGA，用串口终端（115200 baud）接收，确认输出字节值约为室温 × 2（单位 0.5°C）。

---

## 九、待确认事项

1. **LM75 I2C 地址**：开发板上 A2/A1/A0 的实际接法。若全接 GND 则为 `7'h48`（默认）。需查开发板原理图确认。

2. **i2c.v 修改范围**：2字节读扩展是否影响现有 I2C 外设（如 I2C 写外设的其他设备）？新 bit[10] 默认为 0，向前兼容。

3. **仿真策略**：I2C 仿真需要 LM75 行为模型。可选：
   - 编写简单 Verilog I2C slave stub（返回固定温度 25°C = 0x1900）
   - 或直接上板验证，跳过功能仿真

4. **超时时间**：RT 指令约需 20,000 周期（400µs），仿真超时已设为 2ms，无需修改。

5. **与现有 I2C 软件接口的兼容性**：目前 SoC 中 I2C 主要通过 SW 驱动（C 代码直接读写寄存器）。RT 硬件指令绕过了软件层，直接在 EX 阶段操作 I2C 控制器，两者不能同时使用，需在程序设计层面保证互斥。