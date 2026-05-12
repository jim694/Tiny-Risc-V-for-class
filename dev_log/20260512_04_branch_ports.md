# 分支/跳转相关端口说明

**日期：** 2026-05-12  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、信号流向总览

```
ex.v ──jump_flag_o──► ctrl.v ──jump_flag_o──► pc_reg.v（更新 PC）
      └─jump_addr_o──►        └─jump_addr_o──►
                              └─hold_flag_o──► if_id.v / id_ex.v（flush）

ex.v ──ex_jump_flag_o──► id.v（通知 ID 级当前有跳转）
ex.v ──ex_jump_flag_o──► clint.v（中断控制器感知跳转状态）
```

---

## 二、各模块相关端口

### ex.v（执行级，分支判断发生处）

| 端口 | 方向 | 含义 |
|------|------|------|
| `jump_flag_o` | output | 本周期是否发生跳转（1=跳转）|
| `jump_addr_o` | output | 跳转目标地址 |
| `hold_flag_o` | output | 是否需要暂停流水线（MUL/DIV 多周期）|

**内部判断信号：**

| 信号 | 含义 |
|------|------|
| `op1_eq_op2` | op1 == op2（用于 BEQ/BNE）|
| `op1_ge_op2_signed` | op1 >= op2（有符号，用于 BGE/BLT）|
| `op1_ge_op2_unsigned` | op1 >= op2（无符号，用于 BGEU/BLTU）|
| `jump_flag`（reg）| ALU/分支类跳转标志 |
| `div_jump_flag`（reg）| 除法完成后的跳转标志 |

**最终输出合并：**
```verilog
assign jump_flag_o = jump_flag || div_jump_flag
                   || (int_assert_i == INT_ASSERT);  // 中断也产生跳转
assign jump_addr_o = int_assert ? int_addr_i
                   : (jump_addr | div_jump_addr);
```

---

### ctrl.v（控制级，优先级仲裁）

| 端口 | 方向 | 含义 |
|------|------|------|
| `jump_flag_i` | input | 来自 ex.v 的跳转请求 |
| `jump_addr_i` | input | 来自 ex.v 的跳转地址 |
| `hold_flag_ex_i` | input | EX 级暂停请求（MUL/DIV）|
| `hold_flag_rib_i` | input | RIB 总线暂停请求（bridge stall）|
| `hold_flag_clint_i` | input | 中断控制器暂停请求 |
| `jtag_halt_flag_i` | input | JTAG 暂停请求 |
| `jump_flag_o` | output | 透传给 pc_reg |
| `jump_addr_o` | output | 透传给 pc_reg |
| `hold_flag_o` | output | 综合暂停信号，发给流水线各级 |

**优先级（高→低）：**

```verilog
if (jump_flag_i || hold_flag_ex_i || hold_flag_clint_i)
    hold_flag_o = Hold_Id;      // 冲刷 if_id + id_ex
else if (hold_flag_rib_i)
    hold_flag_o = Hold_Freeze;  // 冻结全部流水线
else if (jtag_halt_flag_i)
    hold_flag_o = Hold_Id;
else
    hold_flag_o = Hold_None;
```

> 跳转（jump_flag）与 MUL/DIV 暂停同优先级，均输出 `Hold_Id`（冲刷错误路径指令）。

---

### pc_reg.v（PC 寄存器）

| 端口 | 方向 | 含义 |
|------|------|------|
| `jump_flag_i` | input | 来自 ctrl.v 的跳转使能 |
| `jump_addr_i` | input | 来自 ctrl.v 的跳转地址 |
| `hold_flag_i` | input | 来自 ctrl.v 的暂停标志 |

**PC 更新优先级：**

```verilog
if      (rst)                         pc_o <= CpuResetAddr;
else if (jump_flag_i == JumpEnable)   pc_o <= jump_addr_i;    // 跳转优先
else if (hold_flag_i >= Hold_Pc)      pc_o <= pc_o;           // 暂停
else                                  pc_o <= pc_o + 4;       // 正常推进
```

---

### id.v（译码级）

| 端口 | 方向 | 含义 |
|------|------|------|
| `ex_jump_flag_i` | input | EX 级当前是否正在跳转 |

用于在译码时感知 EX 有跳转正在发生，避免使用错误的跳转路径操作数（`op1_jump`/`op2_jump`）。

---

### if_id.v / id_ex.v（流水线寄存器）

| 端口 | 方向 | 含义 |
|------|------|------|
| `hold_flag_i` | input | 来自 ctrl.v 的暂停/冻结标志 |

内部根据 `hold_flag_i` 推导：
```verilog
// if_id
flush_en  = (hold_flag == Hold_If || hold_flag == Hold_Id)  // 冲刷为 NOP
freeze_en = (hold_flag == Hold_Freeze)                       // 保持当前值

// id_ex
flush_en  = (hold_flag == Hold_Id)
freeze_en = (hold_flag == Hold_Freeze)
```

---

## 三、hold_flag 编码

| 值 | 宏名 | PC | if_id | id_ex | 使用场景 |
|----|------|----|-------|-------|---------|
| `3'b000` | `Hold_None` | +4 | 推进 | 推进 | 正常执行 |
| `3'b001` | `Hold_Pc` | 冻结 | 推进 | 推进 | （保留）|
| `3'b010` | `Hold_If` | 冻结 | flush | 推进 | （保留）|
| `3'b011` | `Hold_Id` | 冻结 | flush | flush | 跳转/MUL/DIV/中断 |
| `3'b100` | `Hold_Freeze` | 冻结 | 冻结 | 冻结 | bridge stall |