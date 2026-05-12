# RISC-V 寄存器 ABI 命名参考

**日期：** 2026-05-12  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、完整寄存器表

| 编号 | ABI 名 | 保存者 | 用途说明 | 本项目特殊用途 |
|------|--------|--------|---------|--------------|
| x0 | `zero` | — | 硬件恒零，写入被忽略 | 常用于 `addi rd, x0, imm` 加载常数 |
| x1 | `ra` | 调用者 | 返回地址（Return Address）| ADD/LUI 等测试中用作第一操作数 |
| x2 | `sp` | 被调用者 | 栈指针（Stack Pointer）| ADD 测试中借用为第二操作数 |
| x3 | `gp` | — | 全局指针（Global Pointer）| **测试框架：当前测试向量编号（TESTNUM）** |
| x4 | `tp` | — | 线程指针（Thread Pointer）| 测试框架：循环计数器 |
| x5 | `t0` | 调用者 | 临时寄存器 0 | 测试框架：循环上限比较值 |
| x6 | `t1` | 调用者 | 临时寄存器 1 | 测试框架：循环内结果暂存 |
| x7 | `t2` | 调用者 | 临时寄存器 2 | — |
| x8 | `s0/fp` | 被调用者 | 保存寄存器 0 / 帧指针 | — |
| x9 | `s1` | 被调用者 | 保存寄存器 1 | — |
| x10 | `a0` | 调用者 | 函数参数/返回值 0 | AUIPC 测试：结果寄存器 |
| x11 | `a1` | 调用者 | 函数参数/返回值 1 | AUIPC 测试：JAL 返回地址 |
| x12 | `a2` | 调用者 | 函数参数 2 | — |
| x13 | `a3` | 调用者 | 函数参数 3 | — |
| x14 | `a4` | 调用者 | 函数参数 4 | — |
| x15 | `a5` | 调用者 | 函数参数 5 | — |
| x16 | `a6` | 调用者 | 函数参数 6 | — |
| x17 | `a7` | 调用者 | 函数参数 7 | — |
| x18 | `s2` | 被调用者 | 保存寄存器 2 | — |
| x19 | `s3` | 被调用者 | 保存寄存器 3 | — |
| x20 | `s4` | 被调用者 | 保存寄存器 4 | — |
| x21 | `s5` | 被调用者 | 保存寄存器 5 | — |
| x22 | `s6` | 被调用者 | 保存寄存器 6 | — |
| x23 | `s7` | 被调用者 | 保存寄存器 7 | — |
| x24 | `s8` | 被调用者 | 保存寄存器 8 | — |
| x25 | `s9` | 被调用者 | 保存寄存器 9 | — |
| x26 | `s10` | 被调用者 | 保存寄存器 10 | **Testbench：测试完成标志（=1 表示结束）** |
| x27 | `s11` | 被调用者 | 保存寄存器 11 | **Testbench：通过标志（=1 PASS，=0 FAIL）** |
| x28 | `t3` | 调用者 | 临时寄存器 3 | LUI 测试：被测寄存器 |
| x29 | `t4` | 调用者 | 临时寄存器 4 | **测试框架：期望值（与结果比较）** |
| x30 | `t5` | 调用者 | 临时寄存器 5 | **测试框架：被测指令结果** |
| x31 | `t6` | 调用者 | 临时寄存器 6 | — |

---

## 二、本项目测试框架中的寄存器分工

测试程序（Basic_Inst_Example）固定使用如下约定：

```
x26 (s10) = 0  →  测试进行中
x26 (s10) = 1  →  测试结束（PASS 或 FAIL 均设为 1）

x27 (s11) = 1  →  所有测试向量通过（PASS）
x27 (s11) = 0  →  某向量失败（FAIL）

x3  (gp)  = N  →  当前/最后执行的测试向量编号
                   失败时保留 N，用于定位是第几个向量出错

x29 (t4)  =  期望值（每个测试向量前设置）
x30 (t5)  =  被测指令的实际结果
```

典型测试向量结构（以 ADD 测试向量 2 为例）：

```asm
addi  ra,  x0, 0        # x1  = 0  （第一操作数）
addi  sp,  x0, 0        # x2  = 0  （第二操作数）
add   t5,  ra, sp        # x30 = ra + sp = 0  （被测指令）
addi  t4,  x0, 0        # x29 = 0  （期望值）
addi  gp,  x0, 2        # x3  = 2  （测试编号）
bne   t5,  t4, FAIL     # x30 ≠ x29 则跳失败
```

---

## 三、Testbench 中的寄存器监控

`tb/tinyriscv_soc_tb.v` 直接连线到寄存器堆：

```verilog
wire[`RegBus] x3  = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[3];   // 失败编号
wire[`RegBus] x26 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[26];  // 结束标志
wire[`RegBus] x27 = tinyriscv_soc_top_0.u_tinyriscv.u_regs.regs[27];  // 通过标志
```

判断逻辑：

```verilog
wait(x26 == 32'b1)     // 等测试结束
#2000                   // 等待最后写入完成
if (x27 == 32'b1)      // 检查通过标志
    TEST_PASS
else
    TEST_FAIL           // 此时 x3 = 失败的测试向量编号
```

---

## 四、寄存器在 RTL 中的实现

**文件：** `rtl/core/regs.v`

```verilog
reg[`RegBus] regs[0:`RegNum - 1];   // 32 个 32-bit 寄存器
```

**写操作（同步，优先 EX）：**

```verilog
always @ (posedge clk) begin
    if (rst == `RstDisable) begin
        if ((we_i == `WriteEnable) && (waddr_i != `ZeroReg))
            regs[waddr_i] <= wdata_i;   // x0 写保护：ZeroReg = 5'b00000
    end
end
```

**读操作（组合，含 EX→ID 前递）：**

```verilog
always @ (*) begin
    if      (raddr == `ZeroReg)                        rdata = `ZeroWord;
    else if (raddr == waddr_i && we_i == `WriteEnable) rdata = wdata_i;  // 前递
    else                                                rdata = regs[raddr];
end
```

x0（`ZeroReg = 5'b00000`）有双重保护：写入被 `waddr_i != ZeroReg` 过滤，读取直接返回 0。

---

## 五、Vivado 调试时常用信号

在 Vivado 波形窗口中建议添加：

| 信号路径 | 含义 |
|---------|------|
| `u_regs/regs[3]` | 当前测试编号（x3/gp）|
| `u_regs/regs[26]` | 测试完成标志（x26/s10）|
| `u_regs/regs[27]` | 测试通过标志（x27/s11）|
| `u_regs/regs[29]` | 期望值（x29/t4）|
| `u_regs/regs[30]` | 被测指令结果（x30/t5）|
| `u_id_ex/inst_addr_o` | 当前 EX 级指令 PC |
| `u_id_ex/inst_o` | 当前 EX 级指令字（对照解码文档）|