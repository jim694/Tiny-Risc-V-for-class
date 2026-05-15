# IF 指令设计文档：Integrate-and-Fire 神经元

**日期：** 2026-05-15  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、指令概述

IF（Integrate-and-Fire）指令模拟脉冲神经网络中的积分发放神经元：

- **积分模式**（Imm ≠ 0）：将输入电流累加到膜电位寄存器
- **发放判断模式**（Imm = 0）：将膜电位与阈值比较，超阈则发放（输出脉冲 + 复位），否则保持

---

## 二、编码格式

I 型指令：

```
 31      20 19   15 14  12 11    7 6      0
┌──────────┬───────┬──────┬───────┬────────┐
│ imm[11:0]│  rs1  │funct3│  rd   │ opcode │
└──────────┴───────┴──────┴───────┴────────┘
  opcode = 0101111（与 sID/RT 共享）
  funct3 = 010
```

新增 define（defines.v）：

```verilog
`define FUNCT3_IF  3'b010
```

---

## 三、操作数映射

| 字段 | 来源 | 含义 |
|------|------|------|
| `x[rs1]` | inst[19:15]，通用寄存器 | 膜电位 u（当前累积值）|
| `x[rd]`  | inst[11:7]，通用寄存器 | 写回目标（更新后的膜电位或 0）|
| `imm`    | inst[31:20]，符号扩展   | 积分增量（突触输入强度）|
| `x31`    | 硬连线为寄存器 31（阈值 Vth）| 发放阈值 |

**关键设计决策 A：x31 如何读取**

IF 是 I 型指令，inst 中无 rs2 字段。id.v 中对 IF 指令强制令：

```verilog
reg2_raddr_o = 5'd31;   // 当 opcode=INST_SID && funct3=FUNCT3_IF 时
```

使得 ex.v 的 `reg2_rdata_i` 始终为 x31（阈值），不需要额外总线访问。

---

## 四、指令语义（精确定义）

### 4.1 积分模式（inst[31:20] ≠ 0）

```
x[rd] = x[rs1] + sign_ext(imm[11:0])
```

- 纯 ALU 操作，等价于 ADDI
- 单周期完成，**无 stall**

### 4.2 发放判断模式（inst[31:20] = 0）

```
if (x[rs1] ≥ x31)  →  发放分支（Fire）
    UART 发送 x[rs1][7:0]
    x[rd] = 0           // 膜电位复位
else                →  不发放分支（No-Fire）
    x[rd] = x[rs1]      // 膜电位保持
```

比较采用**无符号比较**（膜电位与阈值均为非负值）。

---

## 五、流水线设计方案

### 5.1 总体策略

| 模式 | 是否 stall | 处理方式 |
|------|-----------|---------|
| 积分（imm ≠ 0） | 否 | 组合逻辑直接计算，单周期写 rd |
| 发放判断，不发放 | 否 | 组合逻辑直通，单周期写 rd = rs1 |
| 发放判断，发放 | 是（Hold_Freeze）| EX 状态机驱动 UART 发送，完成后写 rd = 0 |

仿照已有 sID/RT 指令的 Hold_Freeze 模式。

### 5.2 EX 状态机（发放分支）

```
IF_IDLE
  ↓ 检测到 imm=0 && rs1 >= x31 && !if_active && !if_done
IF_SEND
  驱动总线写 UART TX 寄存器（写入 x[rs1][7:0]）
  ↓ 下一拍
IF_WAIT_TX
  轮询 UART 状态寄存器（TX busy bit）
  ↓ TX 完成（busy = 0）
IF_DONE → 组合逻辑写 rd = 0，释放 Hold
  ↓ opcode 离开 IF
回到 IF_IDLE
```

状态寄存器：
```verilog
reg        if_active;   // 发放状态机运行中
reg        if_done;     // 发放完成（粘滞至 opcode 离开，防 Hold_Freeze 重触发）
reg [1:0]  if_state;
reg [4:0]  if_rd_addr;  // 锁存 rd（flush 后 reg_waddr_i 会被清零）
reg [7:0]  if_byte;     // 锁存 x[rs1][7:0]（发放时的膜电位）
```

### 5.3 组合逻辑（ex.v always @(*)）

```verilog
`FUNCT3_IF: begin
    if (inst_i[31:20] != 12'b0) begin
        // ── 积分模式 ──────────────────────────
        reg_wdata = reg1_rdata_i + op2_i;   // rs1 + sign_ext(imm)
        reg_we    = WriteEnable;
        hold_flag = HoldDisable;

    end else begin
        // ── 发放判断模式 ──────────────────────
        if (if_active) begin
            // 发放状态机运行中：持续 hold
            hold_flag = HoldEnable;
            reg_we    = WriteDisable;
            // 驱动总线（由 if_state 决定）
            ...

        end else if (if_done) begin
            // 发放完成：写 rd = 0，释放 hold
            reg_wdata = `ZeroWord;
            reg_we    = WriteEnable;
            hold_flag = HoldDisable;

        end else if (reg1_rdata_i >= reg2_rdata_i) begin
            // 即将发放：hold，等状态机
            hold_flag = HoldEnable;
            reg_we    = WriteDisable;

        end else begin
            // 不发放：直通
            reg_wdata = reg1_rdata_i;
            reg_we    = WriteEnable;
            hold_flag = HoldDisable;
        end
    end
end
```

### 5.4 if_done 粘滞机制

与 sID/RT 保持一致，防止 Hold_Freeze 冻结流水线时指令在 EX 重触发：

```verilog
// 只有当 opcode 离开 IF 指令后才清零 if_done
if (!(opcode == `INST_SID && funct3 == `FUNCT3_IF))
    if_done <= 1'b0;
```

---

## 六、id.v 修改点

在 opcode=INST_SID 的 case 分支中，按 funct3 区分新增 IF：

```verilog
`FUNCT3_IF: begin
    reg1_raddr_o = inst_i[19:15];      // rs1：膜电位
    reg2_raddr_o = 5'd31;              // 硬连线 x31：阈值 Vth
    reg_we_o     = WriteEnable;
    reg_waddr_o  = inst_i[11:7];       // rd
    op1_o        = reg1_rdata_o;
    op2_o        = {{20{inst_i[31]}}, inst_i[31:20]};  // sign_ext(imm)
end
```

---

## 七、修改文件汇总

| 文件 | 改动 |
|------|------|
| `rtl/core/defines.v` | 新增 `` `define FUNCT3_IF 3'b010 `` |
| `rtl/core/id.v` | INST_SID case 内增加 funct3=FUNCT3_IF 分支，强制 reg2_raddr=31 |
| `rtl/core/ex.v` | 增加 IF 组合逻辑分支；新增 if_active/if_done/if_state 状态机 |

---

## 八、关键设计决策汇总

| 决策点 | 选择 | 原因 |
|--------|------|------|
| x31 读取方式 | id.v 强制 reg2_raddr=31 | 不改变总线访问，代价最小 |
| 比较类型 | 无符号 `>=` | 膜电位与阈值均为非负值 |
| 积分模式是否复用 ADDI | 独立 case，逻辑相同 | 保持 opcode/funct3 语义完整性 |
| 不发放分支是否 stall | 否 | 纯组合逻辑直通，单周期 |
| 发放分支 stall 机制 | Hold_Freeze（同 sID/RT）| 保持 EX 段冻结，与已有机制统一 |
| UART 发送字节数 | 1 字节（x[rs1][7:0]）| 仅发送膜电位低 8 位，与 sID 多字节不同 |
| if_done 粘滞 | 是（同 sid_done/rt_done）| 防 Hold_Freeze 期间重触发 |

---

## 九、汇编使用示例

```asm
# 初始化阈值寄存器 x31 = 100（Vth = 100）
li   x31, 100

# x10 = 膜电位初始值 0
li   x10, 0

# 积分：x10 += 30（突触输入）
if   x10, x10, 30       # imm=30, rd=x10, rs1=x10
# x10 = 0 + 30 = 30

# 积分：x10 += 80
if   x10, x10, 80       # x10 = 30 + 80 = 110

# 发放判断：x10(110) >= x31(100) → Fire
if   x10, x10, 0        # 发送 0x6E(110) via UART，x10 = 0

# 发放判断：x10(0) < x31(100) → No Fire
if   x10, x10, 0        # x10 = 0（保持）
```