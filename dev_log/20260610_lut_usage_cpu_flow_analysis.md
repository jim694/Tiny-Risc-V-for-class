# TinyRISCV CPU 指令流与 LUT 过大原因分析

日期：2026-06-10

本文基于当前工程与 `tinyriscv-master` 基线工程的 RTL 对比、`dev_log` 开发记录、以及 Vivado utilization 层级截图进行整理。本文只做学习和分析，不包含 RTL 修改。

## 1. 当前综合现象

用户提供的最近一次 Vivado 结果：

| 层级 | LUT | Reg | 备注 |
| --- | ---: | ---: | --- |
| `tinyriscv_soc_top` | 8813 | 3883 | 顶层总量约 42% LUT |
| `u_tinyriscv` | 5575 | 1972 | CPU 核心仍是主体 |
| `u_ex` | 2228 | 64 | 当前最大 CPU 子模块 |
| `u_id_ex` | 1175 | 185 | 寄存器数不多，但 LUT 仍很高 |
| `u_regs` | 839 | 1024 | 32x32 FF 寄存器堆 + 多读口 mux |
| `u_if_id` | 463 | 64 | `inst_ff` 占 404 LUT |
| `u_jtag_top` | 1638 | 602 | 保持不动，但顶层占比很高 |
| `u_uart_debug` | 761 | 496 | 下载状态机和接收缓冲 |
| `u_pwm` | 309 | 388 | 4 路 32 位计数器/比较器 |
| `u_fpga_mem_bridge` | 279 | 69 | 片内 ROM/RAM 桥接侧 |
| `u_i2c` | 88 | 54 | I2C 本体不大 |

结论：优化 `id_ex` 单点只能缓解表面症状。当前 LUT 过大来自多个设计层面的叠加：EX 内承担了外设事务，自定义指令控制与普通 ALU/访存/CSR 共用一个大输出 mux；流水线寄存器带 flush/freeze 选择；寄存器堆用 FF + 异步读 mux 实现；JTAG/UART/PWM 等模块本身也占显著资源。

## 2. 相对 `tinyriscv-master` 的功能变化

### 2.1 CPU 指令扩展

当前工程新增了 `INST_SID` 自定义 opcode：

```verilog
`define INST_SID    7'b0101111
`define FUNCT3_SID  3'b000
`define FUNCT3_RT   3'b001
`define FUNCT3_IF   3'b010
```

三条扩展功能共享同一个 opcode：

| funct3 | 功能 | RTL 落点 |
| --- | --- | --- |
| `000` | sID：通过 UART 发送学号 | `id.v` 译码，`ex.v` 内部 UART 写事务 FSM |
| `001` | RT：通过 I2C 读取 LM75 温度 | `id.v` 译码，`ex.v` 通过 RIB 访问 I2C 寄存器 |
| `010` | IF：integrate-and-fire 神经元 | `id.v` 强制读 `x31` 作为阈值，`ex.v` 做比较/积分/UART 发放 |

### 2.2 控制信号重构

基线工程中 EX 直接接收完整 `inst_i`，在 EX 中按 `opcode/funct3/funct7` 二次译码。当前工程为了降低 ID/EX 传输宽度，改成 `ExCtrlBus`：

```verilog
`define ExCtrlWidth 6
`define ExCtrlBus 5:0
```

ID 阶段把 R/I/M/Load/Store/Branch/CSR/Custom 统一编码为 `EX_CTRL_*`，ID/EX 只传 6 位控制码，不再传完整指令到 EX。

这减少了 ID/EX 的寄存器位数，但没有消除 EX 的结果选择复杂度。EX 仍需要根据 `ex_ctrl_i` 从 ALU、移位、乘法、除法、访存、CSR、跳转、自定义指令状态机之间选择输出。

### 2.3 流水线暂停语义变化

基线工程的流水线寄存器主要是 hold 后插入 NOP。当前工程新增：

```verilog
`define Hold_Freeze 3'b100
```

`if_id.v` 和 `id_ex.v` 将 hold 拆成：

```verilog
flush_en
freeze_en
```

这用于支持多拍外设事务期间冻结流水线，防止自定义指令重复进入或消失。代价是每组流水寄存器前面都引入 flush/freeze 的数据选择逻辑。Vivado 会把这些控制选择以及上游译码扇入归因到 `inst_ff`、`ex_ctrl_ff`、`op1_ff` 等单个实例下，因此出现“6 个寄存器对应数百 LUT”的现象。

### 2.4 SoC 外设变化

当前工程相对基线做了以下 SoC 级变化：

| 项目 | 基线 | 当前工程 |
| --- | --- | --- |
| Timer/GPIO/SPI | 存在 | SoC 顶层不再例化 |
| PWM | 无 | 新增 `rtl/perips/pwm.v`，挂到 slave 6 |
| I2C | 无 | 新增 `rtl/perips/i2c.v`，挂到 slave 7 |
| ROM/RAM | 直接例化 `rom/ram` | 改成 `rib_mem_bridge` + `fpga_mem_bridge` |
| UART 下载 | 原 131 字节包 | 当前 35 字节包，并加入 `stall_i` 门控 |
| 中断 | timer 驱动 `int_flag[0]` | 当前 `int_flag = INT_NONE` |

### 2.5 存储桥接

当前 SoC 中 ROM/RAM 不再直接挂 RIB，而是通过：

```text
RIB slave0/slave1
  -> rib_mem_bridge
  -> 8-bit ext_out/ext_in
  -> fpga_mem_bridge
  -> 内部 ROM/RAM array
```

`rib_mem_bridge` 每次事务拆成多拍传输，并输出 `stall_o` 冻结 CPU。该模块自身 LUT 只有几百，但它引入了全局 freeze 语义，扩大了 IF/ID、ID/EX、UART debug 等模块的控制条件。

## 3. 当前 CPU 指令流

### 3.1 IF：取指

`pc_reg` 产生 PC，`rib` 的 master1 负责取指。当前 `rib.v` 让 m1 取指默认直通 ROM slave0，并引入 `s0_cs_o/s1_cs_o` 辅助桥接模块区分 ROM/RAM 事务。

取回的指令进入 `if_id.v`：

```verilog
inst_ff
inst_addr_ff
int_ff
```

当前 `if_id` 不只是简单 hold，而是：

```verilog
flush_en  = hold_flag_i == Hold_If || hold_flag_i == Hold_Id
freeze_en = hold_flag_i == Hold_Freeze
```

因此 `inst_ff` 的 LUT 偏高，不是因为 32 个触发器本身大，而是因为每一位前面都有 reset/flush/freeze 选择，并且 `inst` 后续高扇出到 ID 译码。

### 3.2 ID：译码与操作数准备

当前 `id.v` 做了更多工作：

1. 普通 RV32I/RV32M 指令译成 6 位 `ex_ctrl_o`。
2. Load/Store 生成地址基址和立即数。
3. Branch/JAL/JALR/FENCE 预计算 `jump_addr_o`。
4. CSR 立即数类在 ID 阶段构造 `op1_o = {27'h0, rs1}`。
5. 自定义 IF 指令硬连 `reg2_raddr_o = 5'd31`，读取阈值寄存器。

这减少了 EX 二次解码和 ID/EX 位宽，但 ID 的组合译码更宽，且 `ex_ctrl_o` 的生成条件覆盖 40 多个编码。ID 本身在截图中不大，说明 Vivado 更多把译码扇入归到了下游 `id_ex/ex_ctrl_ff` 或 EX 逻辑。

### 3.3 ID/EX：流水线寄存器

当前 `id_ex.v` 传递：

```text
ex_ctrl       6 bit
reg_we        1 bit
reg_waddr     5 bit
reg2_rdata   32 bit
csr_we        1 bit
csr_waddr    32 bit
csr_rdata    32 bit
op1          32 bit
op2          32 bit
jump_addr    32 bit
```

总计约 205 bit。虽然比之前传完整 `inst/reg1/op1_jump/op2_jump` 已经少，但每组 `gen_pipe_dff` 都带 reset、flush、freeze、默认值选择。Vivado 当前把 `ex_ctrl_ff` 标成 585 LUT，说明这里不是寄存器位数问题，而是控制码生成、清零/保持选择、以及下游控制扇出的归因问题。

### 3.4 EX：执行与外设事务

EX 当前承担的工作非常多：

1. ALU：ADD/SUB/SLT/SLTU/XOR/OR/AND。
2. 移位：SLL/SRL/SRA。
3. 乘法：4 个 M 扩展乘法，使用 DSP。
4. 除法：启动 `div`，通过 hold/jump 重执行机制等待结果。
5. Load/Store：生成地址、字节/半字选择、store merge。
6. Branch/JAL/JALR/FENCE：输出跳转控制。
7. CSR：读旧值、写新值。
8. sID：内部 5000 周期等待计数，逐字节写 UART TX。
9. RT：内部状态机访问 I2C CTRL/RDATA 寄存器并轮询 busy。
10. IF：比较 `op1` 与 `x31`，必要时写 UART 并清零 rd。

关键问题是：这些路径最终共用同一组 EX 输出：

```text
reg_wdata/reg_we/reg_waddr
mem_req/mem_we/mem_raddr/mem_waddr/mem_wdata
jump_flag/jump_addr/hold_flag
csr_wdata/csr_we/csr_waddr
```

因此 EX 会综合出很宽的多路选择网络。sID/RT/IF 的 `active/done` 覆盖逻辑又在主 `case (ex_ctrl)` 后再次覆盖这些输出，相当于在普通执行路径之外又叠加了几层优先级 mux。这是 `u_ex` 达到 2228 LUT 的直接原因。

## 4. LUT 过大的详细原因

### 4.1 最大根因：自定义指令把外设控制状态机放进 EX

sID/RT/IF 本质上不是普通一拍 ALU 指令，而是“启动外设事务并等待完成”的多拍操作。当前设计将事务状态保存在 EX 内部：

```text
sid_active/sid_done/sid_byte_cnt/sid_wait_cnt
rt_active/rt_done/rt_state/rt_rd_addr/rt_temp
if_active/if_done/if_rd_addr/if_byte/if_wait_cnt
```

这些状态机还直接驱动 RIB 访存端口和寄存器写回端口。结果是 EX 不再只是执行级，而是同时充当：

```text
ALU + LSU + Branch Unit + CSR Unit + UART command engine + I2C command engine + IF neuron engine
```

这种实现功能上直观，但综合后输出选择器非常宽。EX 的 LUT 增长不是某条 if/case 写法的问题，而是职责边界过大。

### 4.2 `id_ex` 的 LUT 不随寄存器数线性下降

Vivado 报告中 `id_ex` 只有 185 个寄存器，但仍有 1175 LUT，`ex_ctrl_ff` 单独 585 LUT。原因包括：

1. `gen_pipe_dff` 每位都有 reset/flush/freeze/default 选择。
2. `ex_ctrl_i` 的来源是 ID 中覆盖 40 多个 `EX_CTRL_*` 的大译码网络。
3. `ex_ctrl_o` 下游扇出到 EX 的几乎所有功能选择。
4. Vivado 层级归因会把寄存器 D 端前的组合逻辑算到该寄存器实例下。

所以继续只压缩 ID/EX 位宽，收益会越来越低。真正要降 LUT，需要减少 `ex_ctrl` 驱动的全局大 mux，或者把多拍自定义指令事务从 EX 主输出网络中拆出去。

### 4.3 寄存器堆天然消耗大量 LUT mux

`regs.v` 是：

```verilog
reg [31:0] regs[0:31];
```

并且有三个异步读路径：

```text
rdata1_o = regs[raddr1_i]
rdata2_o = regs[raddr2_i]
jtag_data_o = regs[jtag_addr_i]
```

32 个 32 位寄存器用 FF 实现本身带来 1024 个寄存器；三个读口会综合成 32:1 的 32 位 mux 网络。Vivado 中 `u_regs` 的 839 LUT、365 个 F7 mux、112 个 F8 mux 与这个结构吻合。

这部分不是新增功能的单独错误，而是“FF 寄存器堆 + 多异步读口 + JTAG 读口”的结构成本。若 JTAG 保持不动，这部分优化空间有限。

### 4.4 IF/ID 的 `inst_ff` LUT 偏高是控制与扇出归因

`if_id` 的寄存器只有 64 个，但 `inst_ff` 约 404 LUT。主要原因：

1. 指令 32 bit 每位都带 reset/flush/freeze 选择。
2. `inst` 在 ID 中被大量切片用于 opcode/funct3/funct7/rs/rd/imm 译码。
3. 当前 `Hold_Freeze` 支持多拍外设事务，控制逻辑比基线复杂。

因此这个热点不是“指令寄存器 32 bit 太大”，而是控制策略和译码扇出的综合归因。

### 4.5 UART debug 与 JTAG 是顶层固定大头

JTAG 保持不动，但它当前占 1638 LUT、602 Reg，是总 LUT 的约 18.6%。UART debug 占 761 LUT、496 Reg，主要来自：

1. 下载协议状态机。
2. 接收缓冲 `rx_data[0:34]`。
3. 多处 `stall_i` 门控，桥接事务期间冻结下载状态。

这两个模块不属于 CPU 指令流本体，但会显著影响顶层总量。如果目标是顶层 LUT 下降，不能只看 `u_tinyriscv`。

### 4.6 PWM 的成本来自 4 路 32 位计数比较

`pwm.v` 内部有：

```text
A[0..3] 32-bit
B[0..3] 32-bit
cnt[0..3] 32-bit
C[3:0]
```

每路都有 32 位计数器、周期比较、占空比比较。309 LUT、388 Reg 与 4 路 32 位 PWM 的规模一致。若课程功能只要求演示型 PWM，这里存在参数化位宽或通道数优化空间。

### 4.7 I2C 本体不是主要矛盾

`u_i2c` 只有 88 LUT、54 Reg。I2C 状态机虽然代码长，但数据宽度小，寄存器和比较器窄。RT 指令的资源问题主要不在 I2C 模块，而在 EX 里为了 RT 指令轮询 I2C 而增加的控制路径。

### 4.8 存储桥接本体不大，但改变了全局控制

`rib_mem_bridge` 和 `fpga_mem_bridge` 自身分别约 82/279 LUT，但它们引入的 `stall_o` 影响：

1. CPU 顶层 hold。
2. IF/ID 与 ID/EX 的 freeze/flush。
3. UART debug 的状态冻结。
4. 取指与访存事务之间的优先级。

这类控制不会集中体现在桥接模块 LUT 上，而是分散进入流水线寄存器和上游/下游状态机。

## 5. 为什么前几轮优化效果有限

### 5.1 删除 ID/EX 的完整 `inst` 后，逻辑只是迁移

把完整 `inst` 从 ID/EX 删除后，`u_id_ex` 数字下降明显，但 `u_ex` 上升。原因是原来 EX 内部通过 `opcode/funct3/funct7` 译码，现在改为 ID 生成 `ex_ctrl`，综合器会把控制译码和输出选择重新归因到 `ex_ctrl_ff` 与 EX 主 case 上。

### 5.2 6 位 `ex_ctrl` 降低了位宽，但没有减少功能选择数

`ex_ctrl` 从接口上看只有 6 bit，但它代表 40 多个执行动作。EX 仍要从同一组输出端口上选择几十种结果。位宽降低不等于 mux 输入数降低。

### 5.3 删除 `reg1_rdata/op1_jump/op2_jump` 是正确但不是主矛盾

删除重复跨级信号可以减少寄存器位数和部分跳转加法器，但当前 LUT 主体来自：

```text
EX 多功能输出 mux
自定义指令事务状态机
寄存器堆异步读 mux
流水线 freeze/flush 选择
JTAG/UART debug
```

所以该优化功能正确，但对总 LUT 的影响有限是符合预期的。

## 6. 后续优化方向建议

以下只作为后续方案讨论，不在本文中修改代码。

### 6.1 优先级最高：把 sID/RT/IF 从 EX 主数据通路拆成 custom unit

建议 EX 只输出：

```text
custom_start
custom_op
custom_rd
custom_rs1
custom_imm
custom_busy
custom_done
custom_result
```

UART/I2C/IF 的多拍状态机放到独立 `custom_unit` 或外设命令引擎。EX 主 case 只处理 start/busy/result，而不是直接驱动 UART/I2C RIB 事务。这样可以显著减少 EX 输出 mux 的输入数和覆盖层级。

### 6.2 分离 EX 输出网络

当前 EX 所有功能共用一组大 reg/mem/csr/jump 输出。可以按功能拆为：

```text
alu_result
lsu_result / lsu_mem_req
branch_result
csr_result
custom_result
```

最后用更窄的选择合并，或者让各单元独立输出 valid，由顶层仲裁。目标是避免每条指令都进入所有输出端口的大 case。

### 6.3 寄存器堆优化需要权衡 JTAG

`u_regs` 的 LUT 主要来自多读口 mux。可选方向：

1. 保持 JTAG 不动：优化空间有限。
2. JTAG 读口改为复用 CPU 读口或同步读：需要功能/时序重新验证。
3. 改 LUTRAM/BRAM 型寄存器堆：需要处理 x0、写优先、读延迟和 JTAG 可见性。

在“JTAG 保持不动”的约束下，不建议优先动这里。

### 6.4 PWM 可参数化位宽

如果 PWM 只用于 LED 演示，4 路 32 位计数器过宽。可以考虑：

```text
PWM_WIDTH = 16 或 12
通道数按课程要求裁剪
```

这会直接减少 `u_pwm` 的 Reg 和比较器 LUT。

### 6.5 重新评估 ROM/RAM 桥接是否必须经过 8-bit 序列化

当前桥接方案功能上解决了上板存储组织问题，但对 CPU 控制引入全局 freeze。如果课程允许直接片内 ROM/RAM，恢复直接 RIB slave 会减少全局控制复杂度。如果必须保留桥接，则应尽量把 freeze 控制局部化，避免影响不相关模块。

## 7. 当前判断

当前 LUT 不是由单个明显 bug 导致，而是由“课程新增功能直接并入 CPU 执行级”的架构选择导致。尤其是 sID/RT/IF 这类本质上是外设命令的多拍操作，被实现成 EX 内部状态机后，EX 同时承担普通执行、访存、CSR、跳转和外设事务，导致 LUT 明显上升。

如果继续优化，应先从架构边界入手，而不是继续在 `id_ex` 上做局部信号删减。最有价值的下一步是重新设计 custom instruction 执行路径：EX 只做指令启动和结果接收，多拍 UART/I2C/IF 事务移出 EX。
