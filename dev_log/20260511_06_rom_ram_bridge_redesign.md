# ROM/RAM 片外迁移：Bridge 重新设计方案

**日期：** 2026-05-11  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）  
**前置文档：** `20260511_05_rom_ram_offchip_plan.md`

---

## 一、硬性约束

| 约束 | 说明 |
|------|------|
| 片上无 ROM/RAM | SoC 芯片内不允许存在任何存储阵列 |
| 外部 ROM 容量固定 | 256 × 32-bit（1KB），不可更改 |
| 外部 RAM 容量固定 | 16 × 32-bit（64B），不可更改 |
| 物理接口固定 | SoC↔FPGA 仅 8-bit IN + 8-bit OUT，不可增加引脚 |

引脚固定约束直接排除了双 bridge 方案（ROM 和 RAM 各一套接口），ROM 与 RAM 必须**共用同一条 8-bit 串行通道**，串行访问。

---

## 二、原方案失败分析

文档 05 给出的实现方案在仿真中测试失败（23/24 基础用例 FAIL）。以下逐层分析失败原因。

### 2.1 流水线的内存延迟假设

原始 TinyRISCV 三级流水线（IF/ID/EX）的设计前提：

```
ROM/RAM 读操作 = 纯组合逻辑（always @(*)），零延迟
```

RIB 总线无应答握手（no-ACK），仲裁器假定从设备在同一周期即可输出数据。因此，流水线中从未为内存等待设计任何暂停机制。

加入 8-bit 串行 Bridge 后，每次内存访问需要 **8 个 FSM 状态 = 8 个时钟周期**（加上 S_IDLE 检测共 9 周期），与零延迟假设直接冲突。

### 2.2 Hold_Pc 的失效

文档 05 初始计划将 `ctrl.v` 中 RIB hold 分支保持为 `Hold_Pc`（3'b001）。

`Hold_Pc` 的实际行为：

| 信号 | 行为 |
|------|------|
| PC 寄存器 | 冻结（不推进）✓ |
| if_id 寄存器 | **继续推进**（不冻结）|
| id_ex 寄存器 | **继续推进**（不冻结）|

Bridge 发出 stall 的 8 个周期中，PC 虽然冻结（取指地址不变），但 `if_id` 和 `id_ex` 持续推进。`s0_rdata_o` 在 bridge 完成前输出的是 0 或陈旧数据，这些无效数据逐级流入 ID 和 EX，正确指令被冲出流水线。

**结果**：寄存器写操作永远无法完成，x26 始终为 `x`，全部测试 TIMEOUT。

### 2.3 Hold_Id 的失效

将 `ctrl.v` 改为 `Hold_Id`（3'b011）后测试仍然全部失败。

`Hold_Id` 的实际行为由 `gen_pipe_dff` 决定：

```verilog
// rtl/utils/gen_dff.v — gen_pipe_dff 的当前实现
always @ (posedge clk) begin
    if (!rst | hold_en) begin
        qout_r <= def_val;   // hold_en=1 → 输出 def_val（NOP），不是保持当前值
    end else begin
        qout_r <= din;
    end
end
```

当 `hold_en=1` 时，寄存器输出 `def_val`（对 if_id 为全零 NOP，对 id_ex 同样），而**不是保持当前值**。这意味着：

- Bridge 等待期间：if_id 和 id_ex 每个周期都被刷写为 NOP
- 当 bridge 完成、stall 释放时：流水线中没有任何有效指令，寄存器写使能始终为 0

**结果**：与 Hold_Pc 失败原因相同，只是路径不同——正确指令被 NOP 覆盖而非被推出。

### 2.4 根本矛盾

```
┌──────────────────────────────────────────────────────────────┐
│  gen_pipe_dff 的 hold_en 有且仅有一种语义：                    │
│    hold_en = 0 → 锁存新数据（正常推进）                        │
│    hold_en = 1 → 输出 def_val（刷写为 NOP）                   │
│                                                              │
│  "保持当前值，等待内存就绪" 这一语义在现有框架中不存在。        │
└──────────────────────────────────────────────────────────────┘
```

现有框架将"冲刷"和"暂停"混为一谈。对于分支/跳转，刷写为 NOP 是正确的（需要取消错误路径上的指令）；但对于内存等待，需要的是**冻结当前内容**，等内存就绪后继续执行同一条指令。

### 2.5 Taken Branch 的额外问题

即使能解决普通顺序执行的 stall，分支指令仍有额外复杂性：

EX 执行 taken branch 时，PC 跳转到目标地址，但 bridge 已经承诺为原顺序地址发起了事务。Bridge 完成后，`s0_rdata_o` 持有的是顺序地址的指令，而流水线已经在执行跳转目标处的取指。文档 05 中的 `addr_match` 机制仅是部分缓解，不足以覆盖所有情况。

---

## 三、各方案评估

### 3.1 方案 A：时钟减慢 9 倍（Clock Enable）

CPU 每 9 个快时钟推进一次，bridge 跑满速在两个 CE 之间完成事务，CPU 视角"零延迟"。

**在单一 8-bit 接口约束下的问题**：

当 EX 执行 lw/sw（需要 RAM，8 fast cycles）时，IF 同时请求 ROM（也需要 8 fast cycles），两者串行共需 16 fast cycles，超过 9 周期 CE 窗口。必须在 lw/sw 时延伸 CE 至 18 个 fast cycles，即检测 EX 阶段指令类型并动态调整 CE 计数器。这等价于引入了 stall 检测，CE 的简洁性优势丧失。

| 维度 | 方案 A |
|------|--------|
| 电路复杂度 | mod-9 计数器 + lw/sw 检测 + CE 布线至所有寄存器 |
| FPGA 资源 | 略低于方案 B |
| 时序 | CE 边沿与 bridge 完成时刻必须精确对齐，上板验证需格外谨慎 |
| lw/sw 性能 | 1/16 原速（CE 需延伸）|
| 纯 ALU 性能 | 1/8 原速 |

### 3.2 方案 B：多周期 Stall（选用）

修改流水线，使其支持真正的"冻结当前值"暂停语义。Bridge 完成前，所有流水线寄存器保持当前内容；完成后正常推进。

| 维度 | 方案 B |
|------|--------|
| 电路复杂度 | gen_pipe_dff 增加 freeze 控制端 + ctrl.v 新增 hold 模式 |
| FPGA 资源 | 与现有相近（仅流水线寄存器稍增逻辑）|
| 时序 | 单时钟域，无对齐风险 |
| lw/sw 性能 | 1/16 原速（IF 和 EX 串行）|
| 纯 ALU 性能 | 1/8 原速 |
| 可扩展性 | Stall 语义天然适配可变延迟，后续优化更灵活 |

**选用方案 B**，原因：单时钟域时序更安全，lw/sw 冲突由 RIB 优先级自然处理，改动边界清晰。

---

## 四、性能分析

以原始设计（片内 ROM/RAM，1 周期/指令）为基准：

| 指令类型 | 原设计 | Bridge 方案 B |
|----------|--------|--------------|
| 纯 ALU（add/sub/and…）| 1 周期/条 | **8 周期/条**（IF bridge）|
| 跳转（jal/jalr/branch）| 1 周期 + 冲刷 | **8 周期 + 冲刷**（IF bridge）|
| lw | 1 周期 | **16 周期**（IF bridge 8 + EX bridge 8，串行）|
| sw | 1 周期 | **16 周期**（IF bridge 8 + EX bridge 8，串行）|

> lw/sw 期间 IF 和 EX 均需 bridge，由于共用单一 8-bit 通道，两次事务强制串行。
> RIB 优先级：M0（EX）> M1（IF），lw/sw 时 EX 优先得到 bridge，IF 等待下一轮。

---

## 五、修改方案

### 5.1 核心改动：gen_pipe_dff 增加 freeze 语义

当前 `gen_pipe_dff` 中 `hold_en=1` 只能输出 NOP，需拆分为两个独立控制端：

| 控制端 | 语义 | 用途 |
|--------|------|------|
| `flush_en` | 输出 `def_val`（NOP） | 分支/跳转时取消错误路径指令 |
| `freeze_en` | 保持当前寄存器值不变 | 内存等待时冻结流水线 |

优先级：`flush_en > freeze_en > 正常推进`

```verilog
// 修改后的 gen_pipe_dff
always @ (posedge clk) begin
    if (!rst | flush_en)
        qout_r <= def_val;        // 复位或冲刷 → NOP
    else if (!freeze_en)
        qout_r <= din;            // 正常推进
    // freeze_en=1, flush_en=0 → 保持 qout_r 不变
end
```

### 5.2 ctrl.v 新增 Bridge Freeze 模式

Bridge stall 期间需要冻结所有阶段（PC + if_id + id_ex），而不是刷写为 NOP：

- 跳转/分支（现有 Hold_Id）：flush if_id 和 id_ex → NOP（取消错误路径）
- Bridge stall（新增 Hold_Freeze）：freeze PC + if_id + id_ex（保持当前值）

```verilog
// ctrl.v 新增 hold 模式
} else if (hold_flag_rib_i == `HoldEnable) begin
    hold_flag_o = `Hold_Freeze;   // 新定义，冻结全部，不冲刷
```

`Hold_Freeze` 在 pipeline 各级寄存器中：连接 `freeze_en=1`，`flush_en=0`。

### 5.3 rib_mem_bridge.v：FSM 精简（9 周期 → 8 周期）

**优化点**：现有设计的 `S_SEND_CTRL` 状态是一个冗余周期。分析如下：

- `S_IDLE`（pending=1）：stall 已拉高，CPU 已冻结，地址已稳定，`ext_out=0`（无有效输出）
- `S_SEND_CTRL`：捕获地址、发出 CTRL 字节（这件事在 `S_IDLE` 就完全可以做）

将 CTRL 字节的发送与地址捕获直接移至 `S_IDLE`（pending 时），去掉 `S_SEND_CTRL` 状态：

```
旧 FSM（8 状态，9 周期）：
S_IDLE(pending) → S_SEND_CTRL → S_SEND_ADDR → S_DATA0..3 → S_LATCH → S_IDLE(free)

新 FSM（7 状态，8 周期）：
S_IDLE(pending+CTRL) → S_SEND_ADDR → S_DATA0..3 → S_LATCH → S_IDLE(free)
```

优化后逐拍时序（读操作为例）：

```
T  SoC状态       ext_out(SoC)    FPGA收到         FPGA状态        ext_out(FPGA)
0  S_IDLE        CTRL            —                S_IDLE          0
1  S_SEND_ADDR   ADDR            CTRL→帧开始       S_RECV_ADDR     0
2  S_DATA0       WDAT[7:0]       ADDR→读存储体     S_DATA0         rdata[7:0]
3  S_DATA1       WDAT[15:8]      WDAT[7:0]        S_DATA1         rdata[15:8]   ←SoC采rdata[7:0]
4  S_DATA2       WDAT[23:16]     WDAT[15:8]       S_DATA2         rdata[23:16]  ←SoC采rdata[15:8]
5  S_DATA3       WDAT[31:24]     WDAT[23:16]      S_DATA3         rdata[31:24]  ←SoC采rdata[23:16]
6  S_LATCH       0               WDAT[31:24]      S_IDLE          0             ←SoC采rdata[31:24]，锁存
7  S_IDLE(free)  —               —                —               —
```

`S_IDLE` 中 pending=1 时的新逻辑：
```verilog
S_IDLE: begin
    if (any_cs && !transaction_done) begin
        // 捕获地址（CPU 已被 pending 冻住，地址稳定）
        mem_sel_r <= s1_cs_i;
        addr_r    <= s1_cs_i ? s1_addr_i[9:2] : s0_addr_i[9:2];
        we_r      <= s1_cs_i ? s1_we_i   : s0_we_i;
        wdata_r   <= s1_cs_i ? s1_wdata_i : s0_wdata_i;
        // 直接发出 CTRL 字节
        ext_out_o <= {1'b1, s1_cs_i, (s1_cs_i ? s1_we_i : s0_we_i), 5'b0};
        state     <= S_SEND_ADDR;
    end else begin
        ext_out_o <= 8'h0;
    end
end
```

其余机制（`pending`、`transaction_done`、`stall_o`）逻辑不变。`addr_match` 可在有正确 freeze stall 后简化或去除。

### 5.4 tinyriscv_soc_top.v

无结构性变化，接口连接与文档 05 方案相同：
- Slave 0/1 接至 `rib_mem_bridge`
- `stall_o` 连至 CPU 的 `rib_hold_flag_i`
- `ext_mem_out/in` 连至顶层端口

---

## 六、修改计划

### Step 1：修改 `rtl/utils/gen_dff.v`

将 `gen_pipe_dff` 的 `hold_en` 端口拆分为 `flush_en` 和 `freeze_en`，更新内部逻辑。  
同步更新所有使用 `gen_pipe_dff` 的调用处（if_id、id_ex 等流水线寄存器）。

### Step 2：修改 `rtl/core/ctrl.v`

新增 `Hold_Freeze` 定义（或复用现有编码并更新语义），将 bridge stall 分支改为输出 `Hold_Freeze`，与跳转分支的 `Hold_Id`（NOP 冲刷）区分。

### Step 3：修改 `rtl/core/defines.v`

新增 `Hold_Freeze` 宏定义，更新 `Hold_Flag_Bus` 位宽（如需要）。

### Step 4：重写 `rtl/bridge/rib_mem_bridge.v`

去掉 `S_SEND_CTRL` 状态，将 CTRL 发送与地址捕获移入 `S_IDLE`（pending=1 分支）。状态机从 8 状态简化为 7 状态，事务周期从 9 降至 8。具体改动：

- `localparam` 中删除 `S_SEND_CTRL`，其余状态编号不变
- `S_IDLE` 的 `always` 块：pending 时捕获 addr/we/wdata，输出 CTRL，跳转至 `S_SEND_ADDR`（原 `S_SEND_ADDR` 逻辑不变）
- 删除 `S_SEND_CTRL` 的 `case` 分支
- `addr_match` 检查可简化或去除（freeze stall 正确后 taken branch 导致的不一致减少）

### Step 5：验证 `rtl/bridge/fpga_mem_bridge.v`

FPGA 侧 FSM 无需修改（协议本身正确），确认与 SoC 侧时序对齐（S_RECV_ADDR 中用 `ext_in_i` 直接组合读而非 `addr_r`）。

### Step 6：修改 `rtl/core/rib.v`（已完成）

`s0_cs_o` / `s1_cs_o` 新增已在当前 WIP 提交中完成，无需重复。

### Step 7：回归仿真

运行全部 ISA 测试（`python sim/test_all_isa.py`），目标：**48/48 PASS**。  
优先验证：inst_simple（纯 ALU）→ branch 类 → load/store 类。

---

## 七、未解决问题与后续优化

| 问题 | 影响 | 备注 |
|------|------|------|
| lw/sw 串行化 | 性能 1/16 原速 | 硬约束（单 8-bit 接口）导致，无法优化 |
| 64B RAM 容量极小 | 复杂程序 stack 溢出 | 固定约束，测试用例需适配 |
| 取指效率低 | 8 周期/指令（已优化，理论下限）| 无法进一步压缩（4字节数据+协议开销）|
| taken branch 二次取指 | 浪费 9 周期 | 有了正确 freeze stall 后影响减小，可后续优化 |
