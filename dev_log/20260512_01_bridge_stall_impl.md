# Bridge 多周期 Stall 实现与流水线冻结改造

**日期：** 2026-05-12  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）  
**前置文档：** `20260511_06_rom_ram_bridge_redesign.md`

---

## 一、实施背景

文档 06 确定了两个核心改动方向：

1. **gen_pipe_dff 增加 freeze 语义**：现有 `hold_en=1` 只能输出 NOP（冲刷），需新增"保持当前值"语义用于 bridge stall。
2. **rib_mem_bridge FSM 优化**：将 S_SEND_CTRL 合并入 S_IDLE，从 9 周期缩短至 8 周期（理论下限）。

本文档记录上述两项改动的具体实现细节与验证结果。

---

## 二、gen_pipe_dff 改造（`rtl/utils/gen_dff.v`）

### 2.1 原有问题

```verilog
// 改动前：hold_en=1 只能输出 def_val（NOP），无法保持当前值
always @ (posedge clk) begin
    if (!rst | hold_en)
        qout_r <= def_val;   // 冲刷为 NOP
    else
        qout_r <= din;
end
```

原设计将"分支冲刷（flush to NOP）"和"流水线暂停（hold current value）"两种语义混用同一个 `hold_en` 端口，导致 bridge stall 期间无法冻结流水线寄存器。

### 2.2 改造方案

拆分为两个独立控制端：

| 控制端 | 语义 | 用途 |
|--------|------|------|
| `flush_en` | 输出 `def_val`（NOP） | 分支/跳转时冲刷错误路径 |
| `freeze_en` | 保持当前寄存器值不变 | bridge stall 期间冻结流水线 |

优先级：`flush_en > freeze_en > 正常推进`

```verilog
// 改动后
always @ (posedge clk) begin
    if (!rst | flush_en)
        qout_r <= def_val;        // 复位或分支冲刷
    else if (!freeze_en)
        qout_r <= din;            // 正常推进
    // freeze_en=1, flush_en=0 → qout_r 保持不变
end
```

### 2.3 调用处更新

**if_id.v**（3 个 DFF）：
```verilog
// 改动前：wire hold_en = (hold_flag_i >= `Hold_If);
// 改动后：
wire flush_en  = (hold_flag_i == `Hold_If || hold_flag_i == `Hold_Id);
wire freeze_en = (hold_flag_i == `Hold_Freeze);
// 所有 gen_pipe_dff 调用：(clk, rst, hold_en, ...) → (clk, rst, flush_en, freeze_en, ...)
```

**id_ex.v**（11 个 DFF）：
```verilog
// 改动前：wire hold_en = (hold_flag_i >= `Hold_Id);
// 改动后：
wire flush_en  = (hold_flag_i == `Hold_Id);
wire freeze_en = (hold_flag_i == `Hold_Freeze);
```

---

## 三、Hold_Freeze 新增（`rtl/core/defines.v`）

```verilog
`define Hold_None   3'b000   // 不暂停
`define Hold_Pc     3'b001   // 仅冻结 PC
`define Hold_If     3'b010   // 冲刷 if_id
`define Hold_Id     3'b011   // 冲刷 if_id + id_ex（分支/跳转）
`define Hold_Freeze 3'b100   // 冻结 PC + if_id + id_ex（bridge stall）
```

**各模块兼容性验证：**

| 模块 | 使用方式 | Hold_Freeze(4) 效果 |
|------|---------|-------------------|
| pc_reg.v | `hold_flag >= Hold_Pc`（≥1）| 4≥1 → PC 冻结 ✓ |
| if_id.v | 精确匹配 `==Hold_Id` / `==Hold_Freeze` | freeze_en=1 → 保持 ✓ |
| id_ex.v | 精确匹配 | freeze_en=1 → 保持 ✓ |
| clint.v | 仅声明端口，未使用 | 无影响 ✓ |

---

## 四、ctrl.v 修改（`rtl/core/ctrl.v`）

将 bridge stall 分支的输出从 `Hold_Pc` 改为 `Hold_Freeze`：

```verilog
// 改动前
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Pc;   // 仅冻结 PC，if_id/id_ex 继续流动

// 改动后
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Freeze;  // 冻结全部：PC + if_id + id_ex
```

**优先级保持不变：** jump/hold_ex/hold_clint > hold_rib > jtag_halt

---

## 五、rib_mem_bridge FSM 优化（`rtl/bridge/rib_mem_bridge.v`）

### 5.1 优化原理

原设计 S_SEND_CTRL 状态的唯一作用是捕获地址并发出 CTRL 字节。但 S_IDLE 的 pending=1 时 CPU 已被 Hold_Freeze 冻住，地址已稳定，可在 S_IDLE 直接完成这两个动作，省去一个状态。

```
旧 FSM（8 状态，9 周期）：
S_IDLE(pending) → S_SEND_CTRL → S_SEND_ADDR → S_DATA0~3 → S_LATCH → S_IDLE(free)

新 FSM（7 状态，8 周期）：
S_IDLE(pending+CTRL) → S_SEND_ADDR → S_DATA0~3 → S_LATCH → S_IDLE(free)
```

### 5.2 8 周期时序对齐（以读 ROM[0] 为例）

```
T  SoC 状态      ext_out(SoC)    FPGA 状态     ext_out(FPGA)   SoC 采样
0  S_IDLE        CTRL            S_IDLE         0               —
1  S_SEND_ADDR   ADDR            S_RECV_ADDR    0               —
2  S_DATA0       WDAT[7:0]       S_DATA0        rdata[7:0]      —
3  S_DATA1       WDAT[15:8]      S_DATA1        rdata[15:8]     rdata[7:0] ✓
4  S_DATA2       WDAT[23:16]     S_DATA2        rdata[23:16]    rdata[15:8] ✓
5  S_DATA3       WDAT[31:24]     S_DATA3        rdata[31:24]    rdata[23:16] ✓
6  S_LATCH       0               S_IDLE         0               rdata[31:24]，锁存 ✓
7  S_IDLE(free)  —               —              —               CPU 推进
```

### 5.3 addr_match 逻辑去除

原设计的 `addr_match` 用于检测 taken branch 导致 PC 改变。有了正确的 Hold_Freeze stall，bridge 事务期间 PC 始终被冻结，addr 不会改变，addr_match 恒为真，逻辑可安全删除，S_LATCH 直接锁存数据。

### 5.4 fpga_mem_bridge.v

FPGA 侧 FSM 无需修改。新协议的 CTRL 字节提前 1 拍到达 FPGA，FPGA 状态机整体提前 1 拍，采样对齐关系不变。

---

## 六、8 周期下限分析

| 周期 | 用途 | 可否省略 |
|------|------|---------|
| T=0 | 发 CTRL（帧头，含 mem_sel/we）| 否（协议必须） |
| T=1 | 发 ADDR（8 位字地址）| 否（ROM 256 字需 8 位，不可合并入 CTRL） |
| T=2 | 流水延迟（FPGA 收到 ADDR 后读存储体，注册输出需 1 拍） | 否（同步设计固有延迟） |
| T=3~6 | 接收 4 字节 rdata（32÷8=4） | 否（数据宽度固定） |
| T=7 | CPU free cycle（推进 PC、释放 cs） | 否（否则立即重触发 pending） |

**8 周期为该协议的理论下限。**

---

## 七、性能数据

| 指令类型 | 原设计 | 本次实现 |
|----------|--------|---------|
| 纯 ALU | 1 周期/条 | **8 周期/条** |
| lw / sw | 1 周期/条 | **16 周期/条**（IF+EX 串行，单通道约束） |
| 分支（taken）| 1 周期 + 冲刷 | **8 周期 + 冲刷** |

---

## 八、仿真验证结果

**测试集：** Basic_Inst_Example（24 个测试用例）  
**结果：14/24 PASS**

| 结果 | 测试项 |
|------|--------|
| **PASS（14）** | andi, auipc, beq, bge, bgeu, blt, bne, div, divu, ori, rem, remu, simple, xori |
| **FAIL（10）** | add, bltu, jal, jalr, lui, slli, slti, sltiu, srai, srli |

相比 WIP 阶段（仅 inst_simple 通过），本次改动使通过率从 1/24 提升至 14/24。  
FAIL 的 10 个用例均表现为仿真超时（程序进入无限循环），说明是**功能性错误**而非超时限制，需进一步排查具体指令路径上的流水线问题。

---

## 九、变更文件汇总

| 文件 | 变更类型 | 说明 |
|------|---------|------|
| `rtl/core/defines.v` | 修改 | 新增 `Hold_Freeze 3'b100` |
| `rtl/utils/gen_dff.v` | 修改 | `hold_en` → `flush_en` + `freeze_en` |
| `rtl/core/if_id.v` | 修改 | 更新 hold 逻辑 + 3 个 DFF 调用 |
| `rtl/core/id_ex.v` | 修改 | 更新 hold 逻辑 + 11 个 DFF 调用 |
| `rtl/core/ctrl.v` | 修改 | rib stall → `Hold_Freeze` |
| `rtl/bridge/rib_mem_bridge.v` | 重写 | 7 状态 FSM，8 周期，去除 addr_match |
