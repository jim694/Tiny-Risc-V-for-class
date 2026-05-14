# sID 自定义指令实现

**日期：** 2026-05-14  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、功能描述

新增自定义指令 **sID**（Send ID）。CPU 译码到该指令时，通过 UART 依次发送学号 `1234567890` 各位数字的 ASCII 码，共 10 字节，发送完毕后流水线继续推进。

| 字节序 | 字符 | ASCII（十六进制）|
|--------|------|----------------|
| 0 | '1' | 0x31 |
| 1 | '2' | 0x32 |
| 2 | '3' | 0x33 |
| 3 | '4' | 0x34 |
| 4 | '5' | 0x35 |
| 5 | '6' | 0x36 |
| 6 | '7' | 0x37 |
| 7 | '8' | 0x38 |
| 8 | '9' | 0x39 |
| 9 | '0' | 0x30 |

---

## 二、指令编码

采用 I-type 格式，rd、rs1、Imm 均为 0：

```
 31      20 19  15 14  12 11   7 6      0
┌──────────┬──────┬──────┬──────┬────────┐
│ 000…000  │00000 │ 000  │00000 │0101111 │
└──────────┴──────┴──────┴──────┴────────┘
```

- **opcode** = `0101111`（RV32A AMO 域，本项目未实现 A 扩展，安全复用）
- **机器码** = `0x0000_002F`

C 内联汇编写法：

```c
asm volatile(".insn i 0x2f, 0, x0, x0, 0");
```

---

## 三、实现方案

### 3.1 整体思路

sID 是多周期指令，在 EX 阶段运行内置状态机，逐字节写 UART TX 寄存器（`0x3000_000C`），期间通过 `hold_flag_o` 持续暂停流水线。

### 3.2 Hold 机制的关键问题

三级流水线中 **Hold_Id**（由 EX `hold_flag_o=1` 触发）会 **flush id_ex**，使 EX 下一拍看到 NOP 而非 sID 指令。若 hold 逻辑依赖 `opcode == INST_SID`，指令一旦被冲刷就无法继续 hold，流水线立即恢复，状态机提前终止。

**解决方案**：将 hold 和总线驱动逻辑移出 `case(opcode)` 语句，在其**外部**由 `sid_active` 寄存器覆盖，不依赖 opcode：

```verilog
// case(opcode) 内：第一拍触发 hold
`INST_SID: begin
    hold_flag = `HoldEnable;  // 立即 hold，等状态机启动
    mem_req = `RIB_NREQ;
    // ...
end

// case(opcode) 之后：sid_active=1 期间持续覆盖，与 opcode 无关
if (sid_active) begin
    hold_flag = `HoldEnable;
    if (sid_wait_cnt == 13'h0) begin
        mem_req     = `RIB_REQ;
        mem_we      = `WriteEnable;
        mem_waddr_o = 32'h3000_000C;   // UART_TXDATA
        mem_wdata_o = {24'h0, sid_byte};
    end else begin
        mem_req = `RIB_NREQ;
        mem_we  = `WriteDisable;
    end
end
```

### 3.3 状态机设计

在 `ex.v` 中新增时序逻辑（为此给 ex 模块加了 `clk` 和 `rst` 端口）：

```
寄存器：
  sid_active   [0]     执行中标志
  sid_done     [0]     完成标志，防止流水线恢复后瞬间重触发
  sid_byte_cnt [3:0]   当前发送的字节索引（0~9）
  sid_wait_cnt [12:0]  字节间等待计数器（0~N_WAIT）

参数：
  SID_N_WAIT = 5000    > 4340 cycles/byte @ 115200baud, 50MHz

状态转移：
  检测到 INST_SID（首拍）  → sid_active=1, cnt 清零
  sid_active=1, wait_cnt<N_WAIT → wait_cnt++
  sid_active=1, wait_cnt=N_WAIT →
      byte_cnt<9: wait_cnt=0, byte_cnt++（发下一字节）
      byte_cnt=9: sid_active=0, sid_done=1（完成）
  sid_active=0, sid_done=1 → hold=0，流水线恢复，sid_done 次拍清零
```

每次 `sid_wait_cnt == 0` 时向 `0x3000_000C` 写入当前字节的 ASCII 码。

### 3.4 UART 条件

使用前须通过 SW 写使能 UART TX：

```c
*(unsigned int *)0x30000000 = 1;  // uart_ctrl[0] = 1（TX enable）
```

`uart.v` 在 TX 使能且非忙时才接受写入。N_WAIT=5000 > 4340（每字节传输时间），保证相邻写入间 UART 已完成上一字节。

### 3.5 编译产物中的 NOP

编译器在 `.insn` 自定义指令后面自动插了一条 NOP（`0x00000013`）：

```
198: 0000002f    sID
19c: 00000013    nop   ← 编译器有意为之
```

GCC 不知道自定义指令的语义，保守地插入 NOP 作为流水线安全气泡。对本实现无副作用，且与 Hold_Id flush 后 id_ex 保持 NOP 的行为天然兼容。

---

## 四、修改的文件

| 文件 | 改动内容 |
|------|---------|
| `rtl/core/defines.v` | 新增 `` `INST_SID 7'b0101111 `` |
| `rtl/core/id.v` | 新增 INST_SID 译码分支（rd/rs1 均为 0，不读写寄存器）|
| `rtl/core/ex.v` | 新增 `clk`/`rst` 端口；新增 sID 时序状态机；case 外部增加 `sid_active` 覆盖逻辑 |
| `rtl/core/tinyriscv.v` | ex 例化中新增 `.clk(clk)` |
| `tb/tinyriscv_soc_tb.v` | 仿真超时从 500µs 延长至 2ms（sID 发 10 字节需 ~1ms）|

---

## 五、验证

### 5.1 仿真

测试用例：`tests/Extend_Inst_Example/sID/sID_inst.data`

运行方式：

```bash
cd sim
python sim_basic_example.py ../tests/Extend_Inst_Example/sID/sID_inst.data
```

仿真结果：
- x26=1（程序正常完成，sID 指令未造成流水线卡死）
- x27=0（该测试程序本身不设置 x27，通过波形验证 UART 输出）
- 波形可在 GTKWave 中观察 `uart_tx_pin`，应依次出现 10 段串行数据

### 5.2 回归

24/24 基本指令仿真全部 PASS，sID 逻辑不影响现有指令。

---

## 六、待完成

- 上板验证：通过串口终端（115200 baud）接收，确认输出字符串 `1234567890`