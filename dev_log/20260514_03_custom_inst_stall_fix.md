# 自定义指令 Hold 机制修复

**日期：** 2026-05-14  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、问题背景

sID（发送学号）和 RT（读温度）均为多周期自定义指令，在 EX 阶段通过内置状态机执行，期间通过 `hold_flag_o=HoldEnable` 持续暂停流水线。

原有实现中，EX stall 触发 `Hold_Id`（值 = 3'b011），经 ctrl.v 输出后作用于各级流水线寄存器：

| 寄存器 | Hold_Id 行为 | Hold_Freeze 行为 |
|--------|-------------|----------------|
| pc_reg | 冻结（不前进）| 冻结 |
| if_id  | **flush（清为 NOP）** | 冻结（保留） |
| id_ex  | flush（清为 NOP）| 冻结（保留）|

---

## 二、已暴露的问题

### 2.1 sID 靠"巧合"运行

sID 指令之所以能正常工作，依赖两个碰巧叠加的条件：

1. **编译器在 `.insn` 指令后自动插入 NOP**（作为保守的流水线安全气泡）：

   ```
   198: 0000002f    sID
   19c: 00000013    nop   ← GCC 插入
   ```

2. **NOP 丢失无副作用**：Hold_Id 把 if_id 里的 NOP flush 掉，但 NOP 本身什么都不做，丢失不影响正确性。

因此 sID 的成功是"运气"，并非设计正确。

### 2.2 RT 指令结果丢失（Hold_Id flush SW）

RT 指令的返回值由编译器用 `%0` 约束绑定输出寄存器，GCC **不插 NOP**，而是将保存返回值的 `sw` 紧跟其后：

```
194: 000017af    RT 指令        ← EX 执行，触发 Hold_Id
198: fef42623    sw a5,-20(s0)  ← 在 if_id 中被 flush！
19c: fec42783    lw a5,-20(s0)  ← PC 冻结在此处
```

Hold_Id 将 if_id 里的 SW 冲刷为 NOP，PC 冻结在 0x19c。RT 完成后，SW 永久消失，LW 读到栈上未初始化的数据，温度值丢失，UART 输出恒为 0。

---

## 三、根本原因分析

EX 多周期 stall 与跳转（JAL/JALR/Branch）被错误地归为同一类，均产生 Hold_Id：

```verilog
// 原 ctrl.v（有问题）
if (jump_flag_i || hold_flag_ex_i || hold_flag_clint_i)
    hold_flag_o = `Hold_Id;   // 两种场景共用，行为不一致
```

但两种场景对 if_id 的需求截然相反：

| 场景 | if_id 应该 | 原因 |
|------|-----------|------|
| 跳转（JAL/Branch）| **flush** | 取到的是错误路径指令，必须丢弃 |
| EX 多周期 stall | **freeze** | 后续指令（如 SW）是有效指令，必须保留 |

---

## 四、修复方案

### 4.1 ctrl.v：区分跳转与 EX stall

将 EX stall 改为产生 `Hold_Freeze`（冻结 if_id，冻结 id_ex），跳转保持产生 `Hold_Id`（flush if_id，flush id_ex）：

```verilog
// 修复后 ctrl.v
if (jump_flag_i == `JumpEnable || hold_flag_clint_i == `HoldEnable) begin
    hold_flag_o = `Hold_Id;      // 跳转/中断：flush if_id 丢弃错误路径
end else if (hold_flag_ex_i == `HoldEnable) begin
    hold_flag_o = `Hold_Freeze;  // EX 多周期：freeze if_id 保留后续指令
end else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Freeze;  // RIB 桥接等待：同前
end
```

**效果：**
- 跳转：if_id flush（丢弃错误路径）✓，id_ex flush（跳转下游空泡）✓
- EX stall：if_id freeze（SW 保留）✓，id_ex freeze（RT/sID 指令留在 EX）✓

### 4.2 id_ex 冻结带来的次生问题：重触发死循环

Hold_Freeze 冻结 id_ex 后，RT/sID 指令长期保留在 id_ex（opcode=INST_SID）。指令完成时（`rt_done`/`sid_done` 置 1）的下一拍，`_done` 标志被 else 分支清零。若此时 RIB 桥接 stall 仍在（Hold_Freeze 来自 RIB），id_ex 依然冻结保留 INST_SID，触发条件 `!rt_done && !rt_active` 立即成立，指令重触发——**死循环**。

```
RT 完成 → rt_done=1
         ↓ 下一拍 else 清零 rt_done=0
RIB stall 持续 → id_ex 冻结，opcode=INST_SID，funct3=001
         ↓
触发条件成立 → RT 再次触发 → 无限循环
```

### 4.3 ex.v：_done 标志粘滞，等 opcode 变化才清零

**RT 指令**（已有 `if(rt_done)` 释放 hold）：

```verilog
// 修复前
end else begin
    rt_done <= 1'b0;   // 无条件清零，下一拍触发条件成立
end

// 修复后
end else begin
    // 只有当 id_ex 推进离开 INST_SID（opcode 改变）才清零
    if (!(opcode == `INST_SID && funct3 == `FUNCT3_RT))
        rt_done <= 1'b0;
end
```

**sID 指令**（需同时补充 `if(sid_done)` hold 释放 + 清零保护）：

```verilog
// 新增：sid_done 时主动释放 hold（否则 INST_SID case 持续 assert hold）
if (sid_done) begin
    hold_flag = `HoldDisable;
end

// 修复后的 else 分支
end else begin
    if (!(opcode == `INST_SID && funct3 == `FUNCT3_SID))
        sid_done <= 1'b0;
end
```

---

## 五、修复后的流水线时序（以 RT 为例）

```
        IF              if_id           id_ex            EX
─────────────────────────────────────────────────────────────
        RT              RT              addi             ...
        SW              SW              RT          ← Hold_Freeze 开始（EX stall）
        LW              SW(冻结)        RT(冻结)    ← id_ex/if_id 均冻结
        ...             SW(冻结)        RT(冻结)    ← RT 状态机运行
        ...             SW(冻结)        RT(冻结)    ← RT 完成，rt_done=1，hold 释放
        ...             LW              SW          ← id_ex 推进到 SW，SW 正常执行
        ...             ...             LW          ← LW 从栈正确取回温度值
```

---

## 六、涉及文件修改

| 文件 | 修改内容 |
|------|---------|
| `rtl/core/ctrl.v` | EX stall 改产生 Hold_Freeze；跳转保持 Hold_Id |
| `rtl/core/ex.v` | 新增 `if(sid_done)` hold 释放块；sID/RT 的 `_done` 标志均等 opcode 变化后再清零 |

---

## 七、验证结果

修复后回归测试：

- 24/24 基本指令仿真全部 PASS（含所有跳转、分支指令）
- sID 仿真：x26=1（正常完成，无死循环）
- RT 仿真：状态机 3/5 长时间停留（正确等待 I2C 事务），完成后不重触发