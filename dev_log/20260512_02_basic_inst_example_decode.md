# Basic_Inst_Example 测试用例解码文档

**日期：** 2026-05-12
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、测试框架说明

每个 `.data` 文件是 ASCII 十六进制格式，每行一条 32-bit RISC-V 机器指令，
通过 `$readmemh` 加载到 ROM，处理器从地址 `0x0000` 开始顺序执行。

**测试用例通用结构（以 inst_add 为例）：**

```
0x0000: addi s10, x0, 0        # x26 = 0（初始化，标记测试进行中）
0x0004: addi s11, x0, 0        # x27 = 0

# --- 测试向量 N ---
        addi gp, x0, N          # x3 = N（测试编号，失败时保留用于输出）
        <operand setup>          # 加载操作数
        <被测指令>               # 执行被测 RISC-V 指令
        <expected value setup>   # 计算期望结果
        bne result, expected, FAIL  # 结果不符则跳到 FAIL 段

# --- PASS 段（所有测试向量通过后到达）---
PASS:   addi s10, x0, 1        # x26 = 1
        addi s11, x0, 1        # x27 = 1
        jal  x0, 0             # j 0  halt（无限循环在此地址）

# --- FAIL 段（某向量失败时跳至此处）---
FAIL:   addi s10, x0, 1        # x26 = 1
        addi s11, x0, 0        # x27 = 0
        jal  x0, 0             # j 0  halt
```

**Testbench 判断逻辑：**

| 状态 | x26 | x27 | 说明 |
|------|-----|-----|------|
| PASS | 1 | 1 | 所有测试向量通过 |
| FAIL | 1 | 0 | 某向量结果错误，x3 = 失败编号 |
| 超时 | 0 | 0 | 程序未在 500000ns 内终止（通常为无限循环）|

---

## 二、当前测试结果汇总

| 测试文件 | 有效指令数 | 主要指令类型 | 结果 |
|---------|-----------|------------|------|
| inst_add | 222 | ADD×27 | FAIL ❌ |
| inst_andi | 120 | ANDI×13 | PASS ✅ |
| inst_auipc | 25 | AUIPC×2, SUB×2 | PASS ✅ |
| inst_beq | 184 | BEQ×27 | PASS ✅ |
| inst_bge | 208 | BGE×33 | PASS ✅ |
| inst_bgeu | 221 | BGEU×33 | PASS ✅ |
| inst_blt | 184 | BLT×27 | PASS ✅ |
| inst_bltu | 197 | BLTU×27 | FAIL ❌ |
| inst_bne | 185 | ADDI×124, BNE×59, JAL×2 | PASS ✅ |
| inst_div | 63 | XOR×9 | PASS ✅ |
| inst_divu | 64 | SRA×9 | PASS ✅ |
| inst_jal | 29 | AUIPC×1 | FAIL ❌ |
| inst_jalr | 61 | AUIPC×6, JALR×5 | FAIL ❌ |
| inst_lui | 32 | SRAI×3 | FAIL ❌ |
| inst_ori | 127 | ORI×13 | PASS ✅ |
| inst_rem | 63 | OR×9 | PASS ✅ |
| inst_remu | 63 | AND×9 | PASS ✅ |
| inst_simple | 5 | ADDI×4, JAL×1 | PASS ✅ |
| inst_slli | 169 | SLLI×24 | FAIL ❌ |
| inst_slti | 165 | SLTI×24 | FAIL ❌ |
| inst_sltiu | 165 | SLTIU×24 | FAIL ❌ |
| inst_srai | 182 | SRAI×24 | FAIL ❌ |
| inst_srli | 176 | SRLI×24 | FAIL ❌ |
| inst_xori | 129 | XORI×13 | PASS ✅ |

---

## 三、各测试文件完整解码

### inst_add  \[FAIL ❌（超时）\]

- **ROM 行数：** 223 行（含 NOP 填充），有效指令 222 条
- **指令分布：** ADD×27, ADDI×140, BNE×37, JAL×2, LUI×16

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00000093  addi    ra, x0, 0
0x000c: 00000113  addi    sp, x0, 0
0x0010: 00208f33  add     t5, ra, sp
0x0014: 00000e93  addi    t4, x0, 0
0x0018: 00200193  addi    gp, x0, 2
0x001c: 35df1263  bne     t5, t4, +836
0x0020: 00100093  addi    ra, x0, 1
0x0024: 00100113  addi    sp, x0, 1
0x0028: 00208f33  add     t5, ra, sp
0x002c: 00200e93  addi    t4, x0, 2
0x0030: 00300193  addi    gp, x0, 3
0x0034: 33df1663  bne     t5, t4, +812
0x0038: 00000093  addi    ra, x0, 0
0x003c: ffff8137  lui     sp, 0xffff8
0x0040: 00208f33  add     t5, ra, sp
0x0044: ffff8eb7  lui     t4, 0xffff8
0x0048: 00500193  addi    gp, x0, 5
0x004c: 31df1a63  bne     t5, t4, +788
0x0050: 800000b7  lui     ra, 0x80000
0x0054: 00000113  addi    sp, x0, 0
0x0058: 00208f33  add     t5, ra, sp
0x005c: 80000eb7  lui     t4, 0x80000
0x0060: 00600193  addi    gp, x0, 6
0x0064: 2fdf1e63  bne     t5, t4, +764
0x0068: 00000093  addi    ra, x0, 0
0x006c: 00008137  lui     sp, 0x00008
0x0070: fff10113  addi    sp, sp, -1
0x0074: 00208f33  add     t5, ra, sp
0x0078: 00008eb7  lui     t4, 0x00008
0x007c: fffe8e93  addi    t4, t4, -1
0x0080: 00800193  addi    gp, x0, 8
0x0084: 2ddf1e63  bne     t5, t4, +732
0x0088: 800000b7  lui     ra, 0x80000
0x008c: fff08093  addi    ra, ra, -1
0x0090: 00000113  addi    sp, x0, 0
0x0094: 00208f33  add     t5, ra, sp
0x0098: 80000eb7  lui     t4, 0x80000
0x009c: fffe8e93  addi    t4, t4, -1
0x00a0: 00900193  addi    gp, x0, 9
0x00a4: 2bdf1e63  bne     t5, t4, +700
0x00a8: 800000b7  lui     ra, 0x80000
0x00ac: 00008137  lui     sp, 0x00008
0x00b0: fff10113  addi    sp, sp, -1
0x00b4: 00208f33  add     t5, ra, sp
0x00b8: 80008eb7  lui     t4, 0x80008
0x00bc: fffe8e93  addi    t4, t4, -1
0x00c0: 00b00193  addi    gp, x0, 11
0x00c4: 29df1e63  bne     t5, t4, +668
0x00c8: 800000b7  lui     ra, 0x80000
0x00cc: fff08093  addi    ra, ra, -1
0x00d0: ffff8137  lui     sp, 0xffff8
0x00d4: 00208f33  add     t5, ra, sp
0x00d8: 7fff8eb7  lui     t4, 0x7fff8
0x00dc: fffe8e93  addi    t4, t4, -1
0x00e0: 00c00193  addi    gp, x0, 12
0x00e4: 27df1e63  bne     t5, t4, +636
0x00e8: 00000093  addi    ra, x0, 0
0x00ec: fff00113  addi    sp, x0, -1
0x00f0: 00208f33  add     t5, ra, sp
0x00f4: fff00e93  addi    t4, x0, -1
0x00f8: 00d00193  addi    gp, x0, 13
0x00fc: 27df1263  bne     t5, t4, +612
0x0100: fff00093  addi    ra, x0, -1
0x0104: 00100113  addi    sp, x0, 1
0x0108: 00208f33  add     t5, ra, sp
0x010c: 00000e93  addi    t4, x0, 0
0x0110: 00e00193  addi    gp, x0, 14
0x0114: 25df1663  bne     t5, t4, +588
0x0118: 00100093  addi    ra, x0, 1
0x011c: 80000137  lui     sp, 0x80000
0x0120: fff10113  addi    sp, sp, -1
0x0124: 00208f33  add     t5, ra, sp
0x0128: 80000eb7  lui     t4, 0x80000
0x012c: 01000193  addi    gp, x0, 16
0x0130: 23df1863  bne     t5, t4, +560
0x0134: 00d00093  addi    ra, x0, 13
0x0138: 00b00113  addi    sp, x0, 11
0x013c: 002080b3  add     ra, ra, sp
0x0140: 01800e93  addi    t4, x0, 24
0x0144: 01100193  addi    gp, x0, 17
0x0148: 21d09c63  bne     ra, t4, +536
0x014c: 00e00093  addi    ra, x0, 14
0x0150: 00b00113  addi    sp, x0, 11
0x0154: 00208133  add     sp, ra, sp
0x0158: 01900e93  addi    t4, x0, 25
0x015c: 01200193  addi    gp, x0, 18
0x0160: 21d11063  bne     sp, t4, +512
0x0164: 00d00093  addi    ra, x0, 13
0x0168: 001080b3  add     ra, ra, ra
0x016c: 01a00e93  addi    t4, x0, 26
0x0170: 01300193  addi    gp, x0, 19
0x0174: 1fd09663  bne     ra, t4, +492
0x0178: 00000213  addi    tp, x0, 0
0x017c: 00d00093  addi    ra, x0, 13
0x0180: 00b00113  addi    sp, x0, 11
0x0184: 00208f33  add     t5, ra, sp
0x0188: 000f0313  addi    t1, t5, 0
0x018c: 00120213  addi    tp, tp, 1
0x0190: 00200293  addi    t0, x0, 2
0x0194: fe5214e3  bne     tp, t0, -24
0x0198: 01800e93  addi    t4, x0, 24
0x019c: 01400193  addi    gp, x0, 20
0x01a0: 1dd31063  bne     t1, t4, +448
0x01a4: 00000213  addi    tp, x0, 0
0x01a8: 00e00093  addi    ra, x0, 14
0x01ac: 00b00113  addi    sp, x0, 11
0x01b0: 00208f33  add     t5, ra, sp
0x01b4: 00000013  addi    x0, x0, 0
0x01b8: 000f0313  addi    t1, t5, 0
0x01bc: 00120213  addi    tp, tp, 1
0x01c0: 00200293  addi    t0, x0, 2
0x01c4: fe5212e3  bne     tp, t0, -28
0x01c8: 01900e93  addi    t4, x0, 25
0x01cc: 01500193  addi    gp, x0, 21
0x01d0: 19d31863  bne     t1, t4, +400
0x01d4: 00000213  addi    tp, x0, 0
0x01d8: 00f00093  addi    ra, x0, 15
0x01dc: 00b00113  addi    sp, x0, 11
0x01e0: 00208f33  add     t5, ra, sp
0x01e4: 00000013  addi    x0, x0, 0
0x01e8: 00000013  addi    x0, x0, 0
0x01ec: 000f0313  addi    t1, t5, 0
0x01f0: 00120213  addi    tp, tp, 1
0x01f4: 00200293  addi    t0, x0, 2
0x01f8: fe5210e3  bne     tp, t0, -32
0x01fc: 01a00e93  addi    t4, x0, 26
0x0200: 01600193  addi    gp, x0, 22
0x0204: 15d31e63  bne     t1, t4, +348
0x0208: 00000213  addi    tp, x0, 0
0x020c: 00d00093  addi    ra, x0, 13
0x0210: 00b00113  addi    sp, x0, 11
0x0214: 00208f33  add     t5, ra, sp
0x0218: 00120213  addi    tp, tp, 1
0x021c: 00200293  addi    t0, x0, 2
0x0220: fe5216e3  bne     tp, t0, -20
0x0224: 01800e93  addi    t4, x0, 24
0x0228: 01700193  addi    gp, x0, 23
0x022c: 13df1a63  bne     t5, t4, +308
0x0230: 00000213  addi    tp, x0, 0
0x0234: 00e00093  addi    ra, x0, 14
0x0238: 00b00113  addi    sp, x0, 11
0x023c: 00000013  addi    x0, x0, 0
0x0240: 00208f33  add     t5, ra, sp
0x0244: 00120213  addi    tp, tp, 1
0x0248: 00200293  addi    t0, x0, 2
0x024c: fe5214e3  bne     tp, t0, -24
0x0250: 01900e93  addi    t4, x0, 25
0x0254: 01800193  addi    gp, x0, 24
0x0258: 11df1463  bne     t5, t4, +264
0x025c: 00000213  addi    tp, x0, 0
0x0260: 00f00093  addi    ra, x0, 15
0x0264: 00b00113  addi    sp, x0, 11
0x0268: 00000013  addi    x0, x0, 0
0x026c: 00000013  addi    x0, x0, 0
0x0270: 00208f33  add     t5, ra, sp
0x0274: 00120213  addi    tp, tp, 1
0x0278: 00200293  addi    t0, x0, 2
0x027c: fe5212e3  bne     tp, t0, -28
0x0280: 01a00e93  addi    t4, x0, 26
0x0284: 01900193  addi    gp, x0, 25
0x0288: 0ddf1c63  bne     t5, t4, +216
0x028c: 00000213  addi    tp, x0, 0
0x0290: 00d00093  addi    ra, x0, 13
0x0294: 00000013  addi    x0, x0, 0
0x0298: 00b00113  addi    sp, x0, 11
0x029c: 00208f33  add     t5, ra, sp
0x02a0: 00120213  addi    tp, tp, 1
0x02a4: 00200293  addi    t0, x0, 2
0x02a8: fe5214e3  bne     tp, t0, -24
0x02ac: 01800e93  addi    t4, x0, 24
0x02b0: 01a00193  addi    gp, x0, 26
0x02b4: 0bdf1663  bne     t5, t4, +172
0x02b8: 00000213  addi    tp, x0, 0
0x02bc: 00b00113  addi    sp, x0, 11
0x02c0: 00d00093  addi    ra, x0, 13
0x02c4: 00208f33  add     t5, ra, sp
0x02c8: 00120213  addi    tp, tp, 1
0x02cc: 00200293  addi    t0, x0, 2
0x02d0: fe5216e3  bne     tp, t0, -20
0x02d4: 01800e93  addi    t4, x0, 24
0x02d8: 01d00193  addi    gp, x0, 29
0x02dc: 09df1263  bne     t5, t4, +132
0x02e0: 00000213  addi    tp, x0, 0
0x02e4: 00b00113  addi    sp, x0, 11
0x02e8: 00e00093  addi    ra, x0, 14
0x02ec: 00000013  addi    x0, x0, 0
0x02f0: 00208f33  add     t5, ra, sp
0x02f4: 00120213  addi    tp, tp, 1
0x02f8: 00200293  addi    t0, x0, 2
0x02fc: fe5214e3  bne     tp, t0, -24
0x0300: 01900e93  addi    t4, x0, 25
0x0304: 01e00193  addi    gp, x0, 30
0x0308: 05df1c63  bne     t5, t4, +88
0x030c: 00f00093  addi    ra, x0, 15
0x0310: 00100133  add     sp, x0, ra
0x0314: 00f00e93  addi    t4, x0, 15
0x0318: 02300193  addi    gp, x0, 35
0x031c: 05d11263  bne     sp, t4, +68
0x0320: 02000093  addi    ra, x0, 32
0x0324: 00008133  add     sp, ra, x0
0x0328: 02000e93  addi    t4, x0, 32
0x032c: 02400193  addi    gp, x0, 36
0x0330: 03d11863  bne     sp, t4, +48
0x0334: 000000b3  add     ra, x0, x0
0x0338: 00000e93  addi    t4, x0, 0
0x033c: 02500193  addi    gp, x0, 37
0x0340: 03d09063  bne     ra, t4, +32
0x0344: 01000093  addi    ra, x0, 16
0x0348: 01e00113  addi    sp, x0, 30
0x034c: 00208033  add     x0, ra, sp
0x0350: 00000e93  addi    t4, x0, 0
0x0354: 02600193  addi    gp, x0, 38
0x0358: 01d01463  bne     x0, t4, +8
0x035c: 00301863  bne     x0, gp, +16
0x0360: 00100d13  addi    s10, x0, 1
0x0364: 00000d93  addi    s11, x0, 0
0x0368: 0000006f  j       0              # halt loop
0x036c: 00100d13  addi    s10, x0, 1
0x0370: 00100d93  addi    s11, x0, 1
0x0374: 0000006f  j       0              # halt loop
```

### inst_andi  \[PASS ✅\]

- **ROM 行数：** 162 行（含 NOP 填充），有效指令 120 条
- **指令分布：** ADDI×71, ANDI×13, BNE×20, JAL×2, LUI×14

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: ff0100b7  lui     ra, 0xff010
0x000c: f0008093  addi    ra, ra, -256
0x0010: f0f0ff13  andi    t5, ra, -241
0x0014: ff010eb7  lui     t4, 0xff010
0x0018: f00e8e93  addi    t4, t4, -256
0x001c: 00200193  addi    gp, x0, 2
0x0020: 1bdf1463  bne     t5, t4, +424
0x0024: 0ff010b7  lui     ra, 0x0ff01
0x0028: ff008093  addi    ra, ra, -16
0x002c: 0f00ff13  andi    t5, ra, 240
0x0030: 0f000e93  addi    t4, x0, 240
0x0034: 00300193  addi    gp, x0, 3
0x0038: 19df1863  bne     t5, t4, +400
0x003c: 00ff00b7  lui     ra, 0x00ff0
0x0040: 0ff08093  addi    ra, ra, 255
0x0044: 70f0ff13  andi    t5, ra, 1807
0x0048: 00f00e93  addi    t4, x0, 15
0x004c: 00400193  addi    gp, x0, 4
0x0050: 17df1c63  bne     t5, t4, +376
0x0054: f00ff0b7  lui     ra, 0xf00ff
0x0058: 00f08093  addi    ra, ra, 15
0x005c: 0f00ff13  andi    t5, ra, 240
0x0060: 00000e93  addi    t4, x0, 0
0x0064: 00500193  addi    gp, x0, 5
0x0068: 17df1063  bne     t5, t4, +352
0x006c: ff0100b7  lui     ra, 0xff010
0x0070: f0008093  addi    ra, ra, -256
0x0074: 0f00f093  andi    ra, ra, 240
0x0078: 00000e93  addi    t4, x0, 0
0x007c: 00600193  addi    gp, x0, 6
0x0080: 15d09463  bne     ra, t4, +328
0x0084: 00000213  addi    tp, x0, 0
0x0088: 0ff010b7  lui     ra, 0x0ff01
0x008c: ff008093  addi    ra, ra, -16
0x0090: 70f0ff13  andi    t5, ra, 1807
0x0094: 000f0313  addi    t1, t5, 0
0x0098: 00120213  addi    tp, tp, 1
0x009c: 00200293  addi    t0, x0, 2
0x00a0: fe5214e3  bne     tp, t0, -24
0x00a4: 70000e93  addi    t4, x0, 1792
0x00a8: 00700193  addi    gp, x0, 7
0x00ac: 11d31e63  bne     t1, t4, +284
0x00b0: 00000213  addi    tp, x0, 0
0x00b4: 00ff00b7  lui     ra, 0x00ff0
0x00b8: 0ff08093  addi    ra, ra, 255
0x00bc: 0f00ff13  andi    t5, ra, 240
0x00c0: 00000013  addi    x0, x0, 0
0x00c4: 000f0313  addi    t1, t5, 0
0x00c8: 00120213  addi    tp, tp, 1
0x00cc: 00200293  addi    t0, x0, 2
0x00d0: fe5212e3  bne     tp, t0, -28
0x00d4: 0f000e93  addi    t4, x0, 240
0x00d8: 00800193  addi    gp, x0, 8
0x00dc: 0fd31663  bne     t1, t4, +236
0x00e0: 00000213  addi    tp, x0, 0
0x00e4: f00ff0b7  lui     ra, 0xf00ff
0x00e8: 00f08093  addi    ra, ra, 15
0x00ec: f0f0ff13  andi    t5, ra, -241
0x00f0: 00000013  addi    x0, x0, 0
0x00f4: 00000013  addi    x0, x0, 0
0x00f8: 000f0313  addi    t1, t5, 0
0x00fc: 00120213  addi    tp, tp, 1
0x0100: 00200293  addi    t0, x0, 2
0x0104: fe5210e3  bne     tp, t0, -32
0x0108: f00ffeb7  lui     t4, 0xf00ff
0x010c: 00fe8e93  addi    t4, t4, 15
0x0110: 00900193  addi    gp, x0, 9
0x0114: 0bd31a63  bne     t1, t4, +180
0x0118: 00000213  addi    tp, x0, 0
0x011c: 0ff010b7  lui     ra, 0x0ff01
0x0120: ff008093  addi    ra, ra, -16
0x0124: 70f0ff13  andi    t5, ra, 1807
0x0128: 00120213  addi    tp, tp, 1
0x012c: 00200293  addi    t0, x0, 2
0x0130: fe5216e3  bne     tp, t0, -20
0x0134: 70000e93  addi    t4, x0, 1792
0x0138: 00a00193  addi    gp, x0, 10
0x013c: 09df1663  bne     t5, t4, +140
0x0140: 00000213  addi    tp, x0, 0
0x0144: 00ff00b7  lui     ra, 0x00ff0
0x0148: 0ff08093  addi    ra, ra, 255
0x014c: 00000013  addi    x0, x0, 0
0x0150: 0f00ff13  andi    t5, ra, 240
0x0154: 00120213  addi    tp, tp, 1
0x0158: 00200293  addi    t0, x0, 2
0x015c: fe5214e3  bne     tp, t0, -24
0x0160: 0f000e93  addi    t4, x0, 240
0x0164: 00b00193  addi    gp, x0, 11
0x0168: 07df1063  bne     t5, t4, +96
0x016c: 00000213  addi    tp, x0, 0
0x0170: f00ff0b7  lui     ra, 0xf00ff
0x0174: 00f08093  addi    ra, ra, 15
0x0178: 00000013  addi    x0, x0, 0
0x017c: 00000013  addi    x0, x0, 0
0x0180: 70f0ff13  andi    t5, ra, 1807
0x0184: 00120213  addi    tp, tp, 1
0x0188: 00200293  addi    t0, x0, 2
0x018c: fe5212e3  bne     tp, t0, -28
0x0190: 00f00e93  addi    t4, x0, 15
0x0194: 00c00193  addi    gp, x0, 12
0x0198: 03df1863  bne     t5, t4, +48
0x019c: 0f007093  andi    ra, x0, 240
0x01a0: 00000e93  addi    t4, x0, 0
0x01a4: 00d00193  addi    gp, x0, 13
0x01a8: 03d09063  bne     ra, t4, +32
0x01ac: 00ff00b7  lui     ra, 0x00ff0
0x01b0: 0ff08093  addi    ra, ra, 255
0x01b4: 70f0f013  andi    x0, ra, 1807
0x01b8: 00000e93  addi    t4, x0, 0
0x01bc: 00e00193  addi    gp, x0, 14
0x01c0: 01d01463  bne     x0, t4, +8
0x01c4: 00301863  bne     x0, gp, +16
0x01c8: 00100d13  addi    s10, x0, 1
0x01cc: 00000d93  addi    s11, x0, 0
0x01d0: 0000006f  j       0              # halt loop
0x01d4: 00100d13  addi    s10, x0, 1
0x01d8: 00100d93  addi    s11, x0, 1
0x01dc: 0000006f  j       0              # halt loop
```

### inst_auipc  \[PASS ✅\]

- **ROM 行数：** 50 行（含 NOP 填充），有效指令 25 条
- **指令分布：** ADDI×12, AUIPC×2, BNE×3, JAL×4, LUI×2, SUB×2

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00002517  auipc   a0, 0x00002
0x000c: 71c50513  addi    a0, a0, 1820
0x0010: 004005ef  jal     a1, +4
0x0014: 40b50533  sub     a0, a0, a1
0x0018: 00002eb7  lui     t4, 0x00002
0x001c: 710e8e93  addi    t4, t4, 1808
0x0020: 00200193  addi    gp, x0, 2
0x0024: 03d51463  bne     a0, t4, +40
0x0028: ffffe517  auipc   a0, 0xffffe
0x002c: 8fc50513  addi    a0, a0, -1796
0x0030: 004005ef  jal     a1, +4
0x0034: 40b50533  sub     a0, a0, a1
0x0038: ffffeeb7  lui     t4, 0xffffe
0x003c: 8f0e8e93  addi    t4, t4, -1808
0x0040: 00300193  addi    gp, x0, 3
0x0044: 01d51463  bne     a0, t4, +8
0x0048: 00301863  bne     x0, gp, +16
0x004c: 00100d13  addi    s10, x0, 1
0x0050: 00000d93  addi    s11, x0, 0
0x0054: 0000006f  j       0              # halt loop
0x0058: 00100d13  addi    s10, x0, 1
0x005c: 00100d93  addi    s11, x0, 1
0x0060: 0000006f  j       0              # halt loop
```

### inst_beq  \[PASS ✅\]

- **ROM 行数：** 226 行（含 NOP 填充），有效指令 184 条
- **指令分布：** ADDI×124, BEQ×27, BNE×31, JAL×2

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 00000113  addi    sp, x0, 0
0x0014: 00208663  beq     ra, sp, +12
0x0018: 2a301863  bne     x0, gp, +688
0x001c: 00301663  bne     x0, gp, +12
0x0020: fe208ee3  beq     ra, sp, -4
0x0024: 2a301263  bne     x0, gp, +676
0x0028: 00300193  addi    gp, x0, 3
0x002c: 00100093  addi    ra, x0, 1
0x0030: 00100113  addi    sp, x0, 1
0x0034: 00208663  beq     ra, sp, +12
0x0038: 28301863  bne     x0, gp, +656
0x003c: 00301663  bne     x0, gp, +12
0x0040: fe208ee3  beq     ra, sp, -4
0x0044: 28301263  bne     x0, gp, +644
0x0048: 00400193  addi    gp, x0, 4
0x004c: fff00093  addi    ra, x0, -1
0x0050: fff00113  addi    sp, x0, -1
0x0054: 00208663  beq     ra, sp, +12
0x0058: 26301863  bne     x0, gp, +624
0x005c: 00301663  bne     x0, gp, +12
0x0060: fe208ee3  beq     ra, sp, -4
0x0064: 26301263  bne     x0, gp, +612
0x0068: 00500193  addi    gp, x0, 5
0x006c: 00000093  addi    ra, x0, 0
0x0070: 00100113  addi    sp, x0, 1
0x0074: 00208463  beq     ra, sp, +8
0x0078: 00301463  bne     x0, gp, +8
0x007c: 24301663  bne     x0, gp, +588
0x0080: fe208ee3  beq     ra, sp, -4
0x0084: 00600193  addi    gp, x0, 6
0x0088: 00100093  addi    ra, x0, 1
0x008c: 00000113  addi    sp, x0, 0
0x0090: 00208463  beq     ra, sp, +8
0x0094: 00301463  bne     x0, gp, +8
0x0098: 22301863  bne     x0, gp, +560
0x009c: fe208ee3  beq     ra, sp, -4
0x00a0: 00700193  addi    gp, x0, 7
0x00a4: fff00093  addi    ra, x0, -1
0x00a8: 00100113  addi    sp, x0, 1
0x00ac: 00208463  beq     ra, sp, +8
0x00b0: 00301463  bne     x0, gp, +8
0x00b4: 20301a63  bne     x0, gp, +532
0x00b8: fe208ee3  beq     ra, sp, -4
0x00bc: 00800193  addi    gp, x0, 8
0x00c0: 00100093  addi    ra, x0, 1
0x00c4: fff00113  addi    sp, x0, -1
0x00c8: 00208463  beq     ra, sp, +8
0x00cc: 00301463  bne     x0, gp, +8
0x00d0: 1e301c63  bne     x0, gp, +504
0x00d4: fe208ee3  beq     ra, sp, -4
0x00d8: 00900193  addi    gp, x0, 9
0x00dc: 00000213  addi    tp, x0, 0
0x00e0: 00000093  addi    ra, x0, 0
0x00e4: fff00113  addi    sp, x0, -1
0x00e8: 1e208063  beq     ra, sp, +480
0x00ec: 00120213  addi    tp, tp, 1
0x00f0: 00200293  addi    t0, x0, 2
0x00f4: fe5216e3  bne     tp, t0, -20
0x00f8: 00a00193  addi    gp, x0, 10
0x00fc: 00000213  addi    tp, x0, 0
0x0100: 00000093  addi    ra, x0, 0
0x0104: fff00113  addi    sp, x0, -1
0x0108: 00000013  addi    x0, x0, 0
0x010c: 1a208e63  beq     ra, sp, +444
0x0110: 00120213  addi    tp, tp, 1
0x0114: 00200293  addi    t0, x0, 2
0x0118: fe5214e3  bne     tp, t0, -24
0x011c: 00b00193  addi    gp, x0, 11
0x0120: 00000213  addi    tp, x0, 0
0x0124: 00000093  addi    ra, x0, 0
0x0128: fff00113  addi    sp, x0, -1
0x012c: 00000013  addi    x0, x0, 0
0x0130: 00000013  addi    x0, x0, 0
0x0134: 18208a63  beq     ra, sp, +404
0x0138: 00120213  addi    tp, tp, 1
0x013c: 00200293  addi    t0, x0, 2
0x0140: fe5212e3  bne     tp, t0, -28
0x0144: 00c00193  addi    gp, x0, 12
0x0148: 00000213  addi    tp, x0, 0
0x014c: 00000093  addi    ra, x0, 0
0x0150: 00000013  addi    x0, x0, 0
0x0154: fff00113  addi    sp, x0, -1
0x0158: 16208863  beq     ra, sp, +368
0x015c: 00120213  addi    tp, tp, 1
0x0160: 00200293  addi    t0, x0, 2
0x0164: fe5214e3  bne     tp, t0, -24
0x0168: 00d00193  addi    gp, x0, 13
0x016c: 00000213  addi    tp, x0, 0
0x0170: 00000093  addi    ra, x0, 0
0x0174: 00000013  addi    x0, x0, 0
0x0178: fff00113  addi    sp, x0, -1
0x017c: 00000013  addi    x0, x0, 0
0x0180: 14208463  beq     ra, sp, +328
0x0184: 00120213  addi    tp, tp, 1
0x0188: 00200293  addi    t0, x0, 2
0x018c: fe5212e3  bne     tp, t0, -28
0x0190: 00e00193  addi    gp, x0, 14
0x0194: 00000213  addi    tp, x0, 0
0x0198: 00000093  addi    ra, x0, 0
0x019c: 00000013  addi    x0, x0, 0
0x01a0: 00000013  addi    x0, x0, 0
0x01a4: fff00113  addi    sp, x0, -1
0x01a8: 12208063  beq     ra, sp, +288
0x01ac: 00120213  addi    tp, tp, 1
0x01b0: 00200293  addi    t0, x0, 2
0x01b4: fe5212e3  bne     tp, t0, -28
0x01b8: 00f00193  addi    gp, x0, 15
0x01bc: 00000213  addi    tp, x0, 0
0x01c0: 00000093  addi    ra, x0, 0
0x01c4: fff00113  addi    sp, x0, -1
0x01c8: 10208063  beq     ra, sp, +256
0x01cc: 00120213  addi    tp, tp, 1
0x01d0: 00200293  addi    t0, x0, 2
0x01d4: fe5216e3  bne     tp, t0, -20
0x01d8: 01000193  addi    gp, x0, 16
0x01dc: 00000213  addi    tp, x0, 0
0x01e0: 00000093  addi    ra, x0, 0
0x01e4: fff00113  addi    sp, x0, -1
0x01e8: 00000013  addi    x0, x0, 0
0x01ec: 0c208e63  beq     ra, sp, +220
0x01f0: 00120213  addi    tp, tp, 1
0x01f4: 00200293  addi    t0, x0, 2
0x01f8: fe5214e3  bne     tp, t0, -24
0x01fc: 01100193  addi    gp, x0, 17
0x0200: 00000213  addi    tp, x0, 0
0x0204: 00000093  addi    ra, x0, 0
0x0208: fff00113  addi    sp, x0, -1
0x020c: 00000013  addi    x0, x0, 0
0x0210: 00000013  addi    x0, x0, 0
0x0214: 0a208a63  beq     ra, sp, +180
0x0218: 00120213  addi    tp, tp, 1
0x021c: 00200293  addi    t0, x0, 2
0x0220: fe5212e3  bne     tp, t0, -28
0x0224: 01200193  addi    gp, x0, 18
0x0228: 00000213  addi    tp, x0, 0
0x022c: 00000093  addi    ra, x0, 0
0x0230: 00000013  addi    x0, x0, 0
0x0234: fff00113  addi    sp, x0, -1
0x0238: 08208863  beq     ra, sp, +144
0x023c: 00120213  addi    tp, tp, 1
0x0240: 00200293  addi    t0, x0, 2
0x0244: fe5214e3  bne     tp, t0, -24
0x0248: 01300193  addi    gp, x0, 19
0x024c: 00000213  addi    tp, x0, 0
0x0250: 00000093  addi    ra, x0, 0
0x0254: 00000013  addi    x0, x0, 0
0x0258: fff00113  addi    sp, x0, -1
0x025c: 00000013  addi    x0, x0, 0
0x0260: 06208463  beq     ra, sp, +104
0x0264: 00120213  addi    tp, tp, 1
0x0268: 00200293  addi    t0, x0, 2
0x026c: fe5212e3  bne     tp, t0, -28
0x0270: 01400193  addi    gp, x0, 20
0x0274: 00000213  addi    tp, x0, 0
0x0278: 00000093  addi    ra, x0, 0
0x027c: 00000013  addi    x0, x0, 0
0x0280: 00000013  addi    x0, x0, 0
0x0284: fff00113  addi    sp, x0, -1
0x0288: 04208063  beq     ra, sp, +64
0x028c: 00120213  addi    tp, tp, 1
0x0290: 00200293  addi    t0, x0, 2
0x0294: fe5212e3  bne     tp, t0, -28
0x0298: 00100093  addi    ra, x0, 1
0x029c: 00000a63  beq     x0, x0, +20
0x02a0: 00108093  addi    ra, ra, 1
0x02a4: 00108093  addi    ra, ra, 1
0x02a8: 00108093  addi    ra, ra, 1
0x02ac: 00108093  addi    ra, ra, 1
0x02b0: 00108093  addi    ra, ra, 1
0x02b4: 00108093  addi    ra, ra, 1
0x02b8: 00300e93  addi    t4, x0, 3
0x02bc: 01500193  addi    gp, x0, 21
0x02c0: 01d09463  bne     ra, t4, +8
0x02c4: 00301863  bne     x0, gp, +16
0x02c8: 00100d13  addi    s10, x0, 1
0x02cc: 00000d93  addi    s11, x0, 0
0x02d0: 0000006f  j       0              # halt loop
0x02d4: 00100d13  addi    s10, x0, 1
0x02d8: 00100d93  addi    s11, x0, 1
0x02dc: 0000006f  j       0              # halt loop
```

### inst_bge  \[PASS ✅\]

- **ROM 行数：** 242 行（含 NOP 填充），有效指令 208 条
- **指令分布：** ADDI×133, BGE×33, BNE×40, JAL×2

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 00000113  addi    sp, x0, 0
0x0014: 0020d663  bge     ra, sp, +12
0x0018: 30301863  bne     x0, gp, +784
0x001c: 00301663  bne     x0, gp, +12
0x0020: fe20dee3  bge     ra, sp, -4
0x0024: 30301263  bne     x0, gp, +772
0x0028: 00300193  addi    gp, x0, 3
0x002c: 00100093  addi    ra, x0, 1
0x0030: 00100113  addi    sp, x0, 1
0x0034: 0020d663  bge     ra, sp, +12
0x0038: 2e301863  bne     x0, gp, +752
0x003c: 00301663  bne     x0, gp, +12
0x0040: fe20dee3  bge     ra, sp, -4
0x0044: 2e301263  bne     x0, gp, +740
0x0048: 00400193  addi    gp, x0, 4
0x004c: fff00093  addi    ra, x0, -1
0x0050: fff00113  addi    sp, x0, -1
0x0054: 0020d663  bge     ra, sp, +12
0x0058: 2c301863  bne     x0, gp, +720
0x005c: 00301663  bne     x0, gp, +12
0x0060: fe20dee3  bge     ra, sp, -4
0x0064: 2c301263  bne     x0, gp, +708
0x0068: 00500193  addi    gp, x0, 5
0x006c: 00100093  addi    ra, x0, 1
0x0070: 00000113  addi    sp, x0, 0
0x0074: 0020d663  bge     ra, sp, +12
0x0078: 2a301863  bne     x0, gp, +688
0x007c: 00301663  bne     x0, gp, +12
0x0080: fe20dee3  bge     ra, sp, -4
0x0084: 2a301263  bne     x0, gp, +676
0x0088: 00600193  addi    gp, x0, 6
0x008c: 00100093  addi    ra, x0, 1
0x0090: fff00113  addi    sp, x0, -1
0x0094: 0020d663  bge     ra, sp, +12
0x0098: 28301863  bne     x0, gp, +656
0x009c: 00301663  bne     x0, gp, +12
0x00a0: fe20dee3  bge     ra, sp, -4
0x00a4: 28301263  bne     x0, gp, +644
0x00a8: 00700193  addi    gp, x0, 7
0x00ac: fff00093  addi    ra, x0, -1
0x00b0: ffe00113  addi    sp, x0, -2
0x00b4: 0020d663  bge     ra, sp, +12
0x00b8: 26301863  bne     x0, gp, +624
0x00bc: 00301663  bne     x0, gp, +12
0x00c0: fe20dee3  bge     ra, sp, -4
0x00c4: 26301263  bne     x0, gp, +612
0x00c8: 00800193  addi    gp, x0, 8
0x00cc: 00000093  addi    ra, x0, 0
0x00d0: 00100113  addi    sp, x0, 1
0x00d4: 0020d463  bge     ra, sp, +8
0x00d8: 00301463  bne     x0, gp, +8
0x00dc: 24301663  bne     x0, gp, +588
0x00e0: fe20dee3  bge     ra, sp, -4
0x00e4: 00900193  addi    gp, x0, 9
0x00e8: fff00093  addi    ra, x0, -1
0x00ec: 00100113  addi    sp, x0, 1
0x00f0: 0020d463  bge     ra, sp, +8
0x00f4: 00301463  bne     x0, gp, +8
0x00f8: 22301863  bne     x0, gp, +560
0x00fc: fe20dee3  bge     ra, sp, -4
0x0100: 00a00193  addi    gp, x0, 10
0x0104: ffe00093  addi    ra, x0, -2
0x0108: fff00113  addi    sp, x0, -1
0x010c: 0020d463  bge     ra, sp, +8
0x0110: 00301463  bne     x0, gp, +8
0x0114: 20301a63  bne     x0, gp, +532
0x0118: fe20dee3  bge     ra, sp, -4
0x011c: 00b00193  addi    gp, x0, 11
0x0120: ffe00093  addi    ra, x0, -2
0x0124: 00100113  addi    sp, x0, 1
0x0128: 0020d463  bge     ra, sp, +8
0x012c: 00301463  bne     x0, gp, +8
0x0130: 1e301c63  bne     x0, gp, +504
0x0134: fe20dee3  bge     ra, sp, -4
0x0138: 00c00193  addi    gp, x0, 12
0x013c: 00000213  addi    tp, x0, 0
0x0140: fff00093  addi    ra, x0, -1
0x0144: 00000113  addi    sp, x0, 0
0x0148: 1e20d063  bge     ra, sp, +480
0x014c: 00120213  addi    tp, tp, 1
0x0150: 00200293  addi    t0, x0, 2
0x0154: fe5216e3  bne     tp, t0, -20
0x0158: 00d00193  addi    gp, x0, 13
0x015c: 00000213  addi    tp, x0, 0
0x0160: fff00093  addi    ra, x0, -1
0x0164: 00000113  addi    sp, x0, 0
0x0168: 00000013  addi    x0, x0, 0
0x016c: 1a20de63  bge     ra, sp, +444
0x0170: 00120213  addi    tp, tp, 1
0x0174: 00200293  addi    t0, x0, 2
0x0178: fe5214e3  bne     tp, t0, -24
0x017c: 00e00193  addi    gp, x0, 14
0x0180: 00000213  addi    tp, x0, 0
0x0184: fff00093  addi    ra, x0, -1
0x0188: 00000113  addi    sp, x0, 0
0x018c: 00000013  addi    x0, x0, 0
0x0190: 00000013  addi    x0, x0, 0
0x0194: 1820da63  bge     ra, sp, +404
0x0198: 00120213  addi    tp, tp, 1
0x019c: 00200293  addi    t0, x0, 2
0x01a0: fe5212e3  bne     tp, t0, -28
0x01a4: 00f00193  addi    gp, x0, 15
0x01a8: 00000213  addi    tp, x0, 0
0x01ac: fff00093  addi    ra, x0, -1
0x01b0: 00000013  addi    x0, x0, 0
0x01b4: 00000113  addi    sp, x0, 0
0x01b8: 1620d863  bge     ra, sp, +368
0x01bc: 00120213  addi    tp, tp, 1
0x01c0: 00200293  addi    t0, x0, 2
0x01c4: fe5214e3  bne     tp, t0, -24
0x01c8: 01000193  addi    gp, x0, 16
0x01cc: 00000213  addi    tp, x0, 0
0x01d0: fff00093  addi    ra, x0, -1
0x01d4: 00000013  addi    x0, x0, 0
0x01d8: 00000113  addi    sp, x0, 0
0x01dc: 00000013  addi    x0, x0, 0
0x01e0: 1420d463  bge     ra, sp, +328
0x01e4: 00120213  addi    tp, tp, 1
0x01e8: 00200293  addi    t0, x0, 2
0x01ec: fe5212e3  bne     tp, t0, -28
0x01f0: 01100193  addi    gp, x0, 17
0x01f4: 00000213  addi    tp, x0, 0
0x01f8: fff00093  addi    ra, x0, -1
0x01fc: 00000013  addi    x0, x0, 0
0x0200: 00000013  addi    x0, x0, 0
0x0204: 00000113  addi    sp, x0, 0
0x0208: 1220d063  bge     ra, sp, +288
0x020c: 00120213  addi    tp, tp, 1
0x0210: 00200293  addi    t0, x0, 2
0x0214: fe5212e3  bne     tp, t0, -28
0x0218: 01200193  addi    gp, x0, 18
0x021c: 00000213  addi    tp, x0, 0
0x0220: fff00093  addi    ra, x0, -1
0x0224: 00000113  addi    sp, x0, 0
0x0228: 1020d063  bge     ra, sp, +256
0x022c: 00120213  addi    tp, tp, 1
0x0230: 00200293  addi    t0, x0, 2
0x0234: fe5216e3  bne     tp, t0, -20
0x0238: 01300193  addi    gp, x0, 19
0x023c: 00000213  addi    tp, x0, 0
0x0240: fff00093  addi    ra, x0, -1
0x0244: 00000113  addi    sp, x0, 0
0x0248: 00000013  addi    x0, x0, 0
0x024c: 0c20de63  bge     ra, sp, +220
0x0250: 00120213  addi    tp, tp, 1
0x0254: 00200293  addi    t0, x0, 2
0x0258: fe5214e3  bne     tp, t0, -24
0x025c: 01400193  addi    gp, x0, 20
0x0260: 00000213  addi    tp, x0, 0
0x0264: fff00093  addi    ra, x0, -1
0x0268: 00000113  addi    sp, x0, 0
0x026c: 00000013  addi    x0, x0, 0
0x0270: 00000013  addi    x0, x0, 0
0x0274: 0a20da63  bge     ra, sp, +180
0x0278: 00120213  addi    tp, tp, 1
0x027c: 00200293  addi    t0, x0, 2
0x0280: fe5212e3  bne     tp, t0, -28
0x0284: 01500193  addi    gp, x0, 21
0x0288: 00000213  addi    tp, x0, 0
0x028c: fff00093  addi    ra, x0, -1
0x0290: 00000013  addi    x0, x0, 0
0x0294: 00000113  addi    sp, x0, 0
0x0298: 0820d863  bge     ra, sp, +144
0x029c: 00120213  addi    tp, tp, 1
0x02a0: 00200293  addi    t0, x0, 2
0x02a4: fe5214e3  bne     tp, t0, -24
0x02a8: 01600193  addi    gp, x0, 22
0x02ac: 00000213  addi    tp, x0, 0
0x02b0: fff00093  addi    ra, x0, -1
0x02b4: 00000013  addi    x0, x0, 0
0x02b8: 00000113  addi    sp, x0, 0
0x02bc: 00000013  addi    x0, x0, 0
0x02c0: 0620d463  bge     ra, sp, +104
0x02c4: 00120213  addi    tp, tp, 1
0x02c8: 00200293  addi    t0, x0, 2
0x02cc: fe5212e3  bne     tp, t0, -28
0x02d0: 01700193  addi    gp, x0, 23
0x02d4: 00000213  addi    tp, x0, 0
0x02d8: fff00093  addi    ra, x0, -1
0x02dc: 00000013  addi    x0, x0, 0
0x02e0: 00000013  addi    x0, x0, 0
0x02e4: 00000113  addi    sp, x0, 0
0x02e8: 0420d063  bge     ra, sp, +64
0x02ec: 00120213  addi    tp, tp, 1
0x02f0: 00200293  addi    t0, x0, 2
0x02f4: fe5212e3  bne     tp, t0, -28
0x02f8: 00100093  addi    ra, x0, 1
0x02fc: 0000da63  bge     ra, x0, +20
0x0300: 00108093  addi    ra, ra, 1
0x0304: 00108093  addi    ra, ra, 1
0x0308: 00108093  addi    ra, ra, 1
0x030c: 00108093  addi    ra, ra, 1
0x0310: 00108093  addi    ra, ra, 1
0x0314: 00108093  addi    ra, ra, 1
0x0318: 00300e93  addi    t4, x0, 3
0x031c: 01800193  addi    gp, x0, 24
0x0320: 01d09463  bne     ra, t4, +8
0x0324: 00301863  bne     x0, gp, +16
0x0328: 00100d13  addi    s10, x0, 1
0x032c: 00000d93  addi    s11, x0, 0
0x0330: 0000006f  j       0              # halt loop
0x0334: 00100d13  addi    s10, x0, 1
0x0338: 00100d93  addi    s11, x0, 1
0x033c: 0000006f  j       0              # halt loop
```

### inst_bgeu  \[PASS ✅\]

- **ROM 行数：** 222 行（含 NOP 填充），有效指令 221 条
- **指令分布：** ADDI×120, BGEU×33, BNE×40, JAL×2, LUI×26

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 00000113  addi    sp, x0, 0
0x0014: 0020f663  bgeu    ra, sp, +12
0x0018: 34301263  bne     x0, gp, +836
0x001c: 00301663  bne     x0, gp, +12
0x0020: fe20fee3  bgeu    ra, sp, -4
0x0024: 32301c63  bne     x0, gp, +824
0x0028: 00300193  addi    gp, x0, 3
0x002c: 00100093  addi    ra, x0, 1
0x0030: 00100113  addi    sp, x0, 1
0x0034: 0020f663  bgeu    ra, sp, +12
0x0038: 32301263  bne     x0, gp, +804
0x003c: 00301663  bne     x0, gp, +12
0x0040: fe20fee3  bgeu    ra, sp, -4
0x0044: 30301c63  bne     x0, gp, +792
0x0048: 00400193  addi    gp, x0, 4
0x004c: fff00093  addi    ra, x0, -1
0x0050: fff00113  addi    sp, x0, -1
0x0054: 0020f663  bgeu    ra, sp, +12
0x0058: 30301263  bne     x0, gp, +772
0x005c: 00301663  bne     x0, gp, +12
0x0060: fe20fee3  bgeu    ra, sp, -4
0x0064: 2e301c63  bne     x0, gp, +760
0x0068: 00500193  addi    gp, x0, 5
0x006c: 00100093  addi    ra, x0, 1
0x0070: 00000113  addi    sp, x0, 0
0x0074: 0020f663  bgeu    ra, sp, +12
0x0078: 2e301263  bne     x0, gp, +740
0x007c: 00301663  bne     x0, gp, +12
0x0080: fe20fee3  bgeu    ra, sp, -4
0x0084: 2c301c63  bne     x0, gp, +728
0x0088: 00600193  addi    gp, x0, 6
0x008c: fff00093  addi    ra, x0, -1
0x0090: ffe00113  addi    sp, x0, -2
0x0094: 0020f663  bgeu    ra, sp, +12
0x0098: 2c301263  bne     x0, gp, +708
0x009c: 00301663  bne     x0, gp, +12
0x00a0: fe20fee3  bgeu    ra, sp, -4
0x00a4: 2a301c63  bne     x0, gp, +696
0x00a8: 00700193  addi    gp, x0, 7
0x00ac: fff00093  addi    ra, x0, -1
0x00b0: 00000113  addi    sp, x0, 0
0x00b4: 0020f663  bgeu    ra, sp, +12
0x00b8: 2a301263  bne     x0, gp, +676
0x00bc: 00301663  bne     x0, gp, +12
0x00c0: fe20fee3  bgeu    ra, sp, -4
0x00c4: 28301c63  bne     x0, gp, +664
0x00c8: 00800193  addi    gp, x0, 8
0x00cc: 00000093  addi    ra, x0, 0
0x00d0: 00100113  addi    sp, x0, 1
0x00d4: 0020f463  bgeu    ra, sp, +8
0x00d8: 00301463  bne     x0, gp, +8
0x00dc: 28301063  bne     x0, gp, +640
0x00e0: fe20fee3  bgeu    ra, sp, -4
0x00e4: 00900193  addi    gp, x0, 9
0x00e8: ffe00093  addi    ra, x0, -2
0x00ec: fff00113  addi    sp, x0, -1
0x00f0: 0020f463  bgeu    ra, sp, +8
0x00f4: 00301463  bne     x0, gp, +8
0x00f8: 26301263  bne     x0, gp, +612
0x00fc: fe20fee3  bgeu    ra, sp, -4
0x0100: 00a00193  addi    gp, x0, 10
0x0104: 00000093  addi    ra, x0, 0
0x0108: fff00113  addi    sp, x0, -1
0x010c: 0020f463  bgeu    ra, sp, +8
0x0110: 00301463  bne     x0, gp, +8
0x0114: 24301463  bne     x0, gp, +584
0x0118: fe20fee3  bgeu    ra, sp, -4
0x011c: 00b00193  addi    gp, x0, 11
0x0120: 800000b7  lui     ra, 0x80000
0x0124: fff08093  addi    ra, ra, -1
0x0128: 80000137  lui     sp, 0x80000
0x012c: 0020f463  bgeu    ra, sp, +8
0x0130: 00301463  bne     x0, gp, +8
0x0134: 22301463  bne     x0, gp, +552
0x0138: fe20fee3  bgeu    ra, sp, -4
0x013c: 00c00193  addi    gp, x0, 12
0x0140: 00000213  addi    tp, x0, 0
0x0144: f00000b7  lui     ra, 0xf0000
0x0148: fff08093  addi    ra, ra, -1
0x014c: f0000137  lui     sp, 0xf0000
0x0150: 2020f663  bgeu    ra, sp, +524
0x0154: 00120213  addi    tp, tp, 1
0x0158: 00200293  addi    t0, x0, 2
0x015c: fe5214e3  bne     tp, t0, -24
0x0160: 00d00193  addi    gp, x0, 13
0x0164: 00000213  addi    tp, x0, 0
0x0168: f00000b7  lui     ra, 0xf0000
0x016c: fff08093  addi    ra, ra, -1
0x0170: f0000137  lui     sp, 0xf0000
0x0174: 00000013  addi    x0, x0, 0
0x0178: 1e20f263  bgeu    ra, sp, +484
0x017c: 00120213  addi    tp, tp, 1
0x0180: 00200293  addi    t0, x0, 2
0x0184: fe5212e3  bne     tp, t0, -28
0x0188: 00e00193  addi    gp, x0, 14
0x018c: 00000213  addi    tp, x0, 0
0x0190: f00000b7  lui     ra, 0xf0000
0x0194: fff08093  addi    ra, ra, -1
0x0198: f0000137  lui     sp, 0xf0000
0x019c: 00000013  addi    x0, x0, 0
0x01a0: 00000013  addi    x0, x0, 0
0x01a4: 1a20fc63  bgeu    ra, sp, +440
0x01a8: 00120213  addi    tp, tp, 1
0x01ac: 00200293  addi    t0, x0, 2
0x01b0: fe5210e3  bne     tp, t0, -32
0x01b4: 00f00193  addi    gp, x0, 15
0x01b8: 00000213  addi    tp, x0, 0
0x01bc: f00000b7  lui     ra, 0xf0000
0x01c0: fff08093  addi    ra, ra, -1
0x01c4: 00000013  addi    x0, x0, 0
0x01c8: f0000137  lui     sp, 0xf0000
0x01cc: 1820f863  bgeu    ra, sp, +400
0x01d0: 00120213  addi    tp, tp, 1
0x01d4: 00200293  addi    t0, x0, 2
0x01d8: fe5212e3  bne     tp, t0, -28
0x01dc: 01000193  addi    gp, x0, 16
0x01e0: 00000213  addi    tp, x0, 0
0x01e4: f00000b7  lui     ra, 0xf0000
0x01e8: fff08093  addi    ra, ra, -1
0x01ec: 00000013  addi    x0, x0, 0
0x01f0: f0000137  lui     sp, 0xf0000
0x01f4: 00000013  addi    x0, x0, 0
0x01f8: 1620f263  bgeu    ra, sp, +356
0x01fc: 00120213  addi    tp, tp, 1
0x0200: 00200293  addi    t0, x0, 2
0x0204: fe5210e3  bne     tp, t0, -32
0x0208: 01100193  addi    gp, x0, 17
0x020c: 00000213  addi    tp, x0, 0
0x0210: f00000b7  lui     ra, 0xf0000
0x0214: fff08093  addi    ra, ra, -1
0x0218: 00000013  addi    x0, x0, 0
0x021c: 00000013  addi    x0, x0, 0
0x0220: f0000137  lui     sp, 0xf0000
0x0224: 1220fc63  bgeu    ra, sp, +312
0x0228: 00120213  addi    tp, tp, 1
0x022c: 00200293  addi    t0, x0, 2
0x0230: fe5210e3  bne     tp, t0, -32
0x0234: 01200193  addi    gp, x0, 18
0x0238: 00000213  addi    tp, x0, 0
0x023c: f00000b7  lui     ra, 0xf0000
0x0240: fff08093  addi    ra, ra, -1
0x0244: f0000137  lui     sp, 0xf0000
0x0248: 1020fa63  bgeu    ra, sp, +276
0x024c: 00120213  addi    tp, tp, 1
0x0250: 00200293  addi    t0, x0, 2
0x0254: fe5214e3  bne     tp, t0, -24
0x0258: 01300193  addi    gp, x0, 19
0x025c: 00000213  addi    tp, x0, 0
0x0260: f00000b7  lui     ra, 0xf0000
0x0264: fff08093  addi    ra, ra, -1
0x0268: f0000137  lui     sp, 0xf0000
0x026c: 00000013  addi    x0, x0, 0
0x0270: 0e20f663  bgeu    ra, sp, +236
0x0274: 00120213  addi    tp, tp, 1
0x0278: 00200293  addi    t0, x0, 2
0x027c: fe5212e3  bne     tp, t0, -28
0x0280: 01400193  addi    gp, x0, 20
0x0284: 00000213  addi    tp, x0, 0
0x0288: f00000b7  lui     ra, 0xf0000
0x028c: fff08093  addi    ra, ra, -1
0x0290: f0000137  lui     sp, 0xf0000
0x0294: 00000013  addi    x0, x0, 0
0x0298: 00000013  addi    x0, x0, 0
0x029c: 0c20f063  bgeu    ra, sp, +192
0x02a0: 00120213  addi    tp, tp, 1
0x02a4: 00200293  addi    t0, x0, 2
0x02a8: fe5210e3  bne     tp, t0, -32
0x02ac: 01500193  addi    gp, x0, 21
0x02b0: 00000213  addi    tp, x0, 0
0x02b4: f00000b7  lui     ra, 0xf0000
0x02b8: fff08093  addi    ra, ra, -1
0x02bc: 00000013  addi    x0, x0, 0
0x02c0: f0000137  lui     sp, 0xf0000
0x02c4: 0820fc63  bgeu    ra, sp, +152
0x02c8: 00120213  addi    tp, tp, 1
0x02cc: 00200293  addi    t0, x0, 2
0x02d0: fe5212e3  bne     tp, t0, -28
0x02d4: 01600193  addi    gp, x0, 22
0x02d8: 00000213  addi    tp, x0, 0
0x02dc: f00000b7  lui     ra, 0xf0000
0x02e0: fff08093  addi    ra, ra, -1
0x02e4: 00000013  addi    x0, x0, 0
0x02e8: f0000137  lui     sp, 0xf0000
0x02ec: 00000013  addi    x0, x0, 0
0x02f0: 0620f663  bgeu    ra, sp, +108
0x02f4: 00120213  addi    tp, tp, 1
0x02f8: 00200293  addi    t0, x0, 2
0x02fc: fe5210e3  bne     tp, t0, -32
0x0300: 01700193  addi    gp, x0, 23
0x0304: 00000213  addi    tp, x0, 0
0x0308: f00000b7  lui     ra, 0xf0000
0x030c: fff08093  addi    ra, ra, -1
0x0310: 00000013  addi    x0, x0, 0
0x0314: 00000013  addi    x0, x0, 0
0x0318: f0000137  lui     sp, 0xf0000
0x031c: 0420f063  bgeu    ra, sp, +64
0x0320: 00120213  addi    tp, tp, 1
0x0324: 00200293  addi    t0, x0, 2
0x0328: fe5210e3  bne     tp, t0, -32
0x032c: 00100093  addi    ra, x0, 1
0x0330: 0000fa63  bgeu    ra, x0, +20
0x0334: 00108093  addi    ra, ra, 1
0x0338: 00108093  addi    ra, ra, 1
0x033c: 00108093  addi    ra, ra, 1
0x0340: 00108093  addi    ra, ra, 1
0x0344: 00108093  addi    ra, ra, 1
0x0348: 00108093  addi    ra, ra, 1
0x034c: 00300e93  addi    t4, x0, 3
0x0350: 01800193  addi    gp, x0, 24
0x0354: 01d09463  bne     ra, t4, +8
0x0358: 00301863  bne     x0, gp, +16
0x035c: 00100d13  addi    s10, x0, 1
0x0360: 00000d93  addi    s11, x0, 0
0x0364: 0000006f  j       0              # halt loop
0x0368: 00100d13  addi    s10, x0, 1
0x036c: 00100d93  addi    s11, x0, 1
0x0370: 0000006f  j       0              # halt loop
```

### inst_blt  \[PASS ✅\]

- **ROM 行数：** 226 行（含 NOP 填充），有效指令 184 条
- **指令分布：** ADDI×124, BLT×27, BNE×31, JAL×2

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 00100113  addi    sp, x0, 1
0x0014: 0020c663  blt     ra, sp, +12
0x0018: 2a301863  bne     x0, gp, +688
0x001c: 00301663  bne     x0, gp, +12
0x0020: fe20cee3  blt     ra, sp, -4
0x0024: 2a301263  bne     x0, gp, +676
0x0028: 00300193  addi    gp, x0, 3
0x002c: fff00093  addi    ra, x0, -1
0x0030: 00100113  addi    sp, x0, 1
0x0034: 0020c663  blt     ra, sp, +12
0x0038: 28301863  bne     x0, gp, +656
0x003c: 00301663  bne     x0, gp, +12
0x0040: fe20cee3  blt     ra, sp, -4
0x0044: 28301263  bne     x0, gp, +644
0x0048: 00400193  addi    gp, x0, 4
0x004c: ffe00093  addi    ra, x0, -2
0x0050: fff00113  addi    sp, x0, -1
0x0054: 0020c663  blt     ra, sp, +12
0x0058: 26301863  bne     x0, gp, +624
0x005c: 00301663  bne     x0, gp, +12
0x0060: fe20cee3  blt     ra, sp, -4
0x0064: 26301263  bne     x0, gp, +612
0x0068: 00500193  addi    gp, x0, 5
0x006c: 00100093  addi    ra, x0, 1
0x0070: 00000113  addi    sp, x0, 0
0x0074: 0020c463  blt     ra, sp, +8
0x0078: 00301463  bne     x0, gp, +8
0x007c: 24301663  bne     x0, gp, +588
0x0080: fe20cee3  blt     ra, sp, -4
0x0084: 00600193  addi    gp, x0, 6
0x0088: 00100093  addi    ra, x0, 1
0x008c: fff00113  addi    sp, x0, -1
0x0090: 0020c463  blt     ra, sp, +8
0x0094: 00301463  bne     x0, gp, +8
0x0098: 22301863  bne     x0, gp, +560
0x009c: fe20cee3  blt     ra, sp, -4
0x00a0: 00700193  addi    gp, x0, 7
0x00a4: fff00093  addi    ra, x0, -1
0x00a8: ffe00113  addi    sp, x0, -2
0x00ac: 0020c463  blt     ra, sp, +8
0x00b0: 00301463  bne     x0, gp, +8
0x00b4: 20301a63  bne     x0, gp, +532
0x00b8: fe20cee3  blt     ra, sp, -4
0x00bc: 00800193  addi    gp, x0, 8
0x00c0: 00100093  addi    ra, x0, 1
0x00c4: ffe00113  addi    sp, x0, -2
0x00c8: 0020c463  blt     ra, sp, +8
0x00cc: 00301463  bne     x0, gp, +8
0x00d0: 1e301c63  bne     x0, gp, +504
0x00d4: fe20cee3  blt     ra, sp, -4
0x00d8: 00900193  addi    gp, x0, 9
0x00dc: 00000213  addi    tp, x0, 0
0x00e0: 00000093  addi    ra, x0, 0
0x00e4: fff00113  addi    sp, x0, -1
0x00e8: 1e20c063  blt     ra, sp, +480
0x00ec: 00120213  addi    tp, tp, 1
0x00f0: 00200293  addi    t0, x0, 2
0x00f4: fe5216e3  bne     tp, t0, -20
0x00f8: 00a00193  addi    gp, x0, 10
0x00fc: 00000213  addi    tp, x0, 0
0x0100: 00000093  addi    ra, x0, 0
0x0104: fff00113  addi    sp, x0, -1
0x0108: 00000013  addi    x0, x0, 0
0x010c: 1a20ce63  blt     ra, sp, +444
0x0110: 00120213  addi    tp, tp, 1
0x0114: 00200293  addi    t0, x0, 2
0x0118: fe5214e3  bne     tp, t0, -24
0x011c: 00b00193  addi    gp, x0, 11
0x0120: 00000213  addi    tp, x0, 0
0x0124: 00000093  addi    ra, x0, 0
0x0128: fff00113  addi    sp, x0, -1
0x012c: 00000013  addi    x0, x0, 0
0x0130: 00000013  addi    x0, x0, 0
0x0134: 1820ca63  blt     ra, sp, +404
0x0138: 00120213  addi    tp, tp, 1
0x013c: 00200293  addi    t0, x0, 2
0x0140: fe5212e3  bne     tp, t0, -28
0x0144: 00c00193  addi    gp, x0, 12
0x0148: 00000213  addi    tp, x0, 0
0x014c: 00000093  addi    ra, x0, 0
0x0150: 00000013  addi    x0, x0, 0
0x0154: fff00113  addi    sp, x0, -1
0x0158: 1620c863  blt     ra, sp, +368
0x015c: 00120213  addi    tp, tp, 1
0x0160: 00200293  addi    t0, x0, 2
0x0164: fe5214e3  bne     tp, t0, -24
0x0168: 00d00193  addi    gp, x0, 13
0x016c: 00000213  addi    tp, x0, 0
0x0170: 00000093  addi    ra, x0, 0
0x0174: 00000013  addi    x0, x0, 0
0x0178: fff00113  addi    sp, x0, -1
0x017c: 00000013  addi    x0, x0, 0
0x0180: 1420c463  blt     ra, sp, +328
0x0184: 00120213  addi    tp, tp, 1
0x0188: 00200293  addi    t0, x0, 2
0x018c: fe5212e3  bne     tp, t0, -28
0x0190: 00e00193  addi    gp, x0, 14
0x0194: 00000213  addi    tp, x0, 0
0x0198: 00000093  addi    ra, x0, 0
0x019c: 00000013  addi    x0, x0, 0
0x01a0: 00000013  addi    x0, x0, 0
0x01a4: fff00113  addi    sp, x0, -1
0x01a8: 1220c063  blt     ra, sp, +288
0x01ac: 00120213  addi    tp, tp, 1
0x01b0: 00200293  addi    t0, x0, 2
0x01b4: fe5212e3  bne     tp, t0, -28
0x01b8: 00f00193  addi    gp, x0, 15
0x01bc: 00000213  addi    tp, x0, 0
0x01c0: 00000093  addi    ra, x0, 0
0x01c4: fff00113  addi    sp, x0, -1
0x01c8: 1020c063  blt     ra, sp, +256
0x01cc: 00120213  addi    tp, tp, 1
0x01d0: 00200293  addi    t0, x0, 2
0x01d4: fe5216e3  bne     tp, t0, -20
0x01d8: 01000193  addi    gp, x0, 16
0x01dc: 00000213  addi    tp, x0, 0
0x01e0: 00000093  addi    ra, x0, 0
0x01e4: fff00113  addi    sp, x0, -1
0x01e8: 00000013  addi    x0, x0, 0
0x01ec: 0c20ce63  blt     ra, sp, +220
0x01f0: 00120213  addi    tp, tp, 1
0x01f4: 00200293  addi    t0, x0, 2
0x01f8: fe5214e3  bne     tp, t0, -24
0x01fc: 01100193  addi    gp, x0, 17
0x0200: 00000213  addi    tp, x0, 0
0x0204: 00000093  addi    ra, x0, 0
0x0208: fff00113  addi    sp, x0, -1
0x020c: 00000013  addi    x0, x0, 0
0x0210: 00000013  addi    x0, x0, 0
0x0214: 0a20ca63  blt     ra, sp, +180
0x0218: 00120213  addi    tp, tp, 1
0x021c: 00200293  addi    t0, x0, 2
0x0220: fe5212e3  bne     tp, t0, -28
0x0224: 01200193  addi    gp, x0, 18
0x0228: 00000213  addi    tp, x0, 0
0x022c: 00000093  addi    ra, x0, 0
0x0230: 00000013  addi    x0, x0, 0
0x0234: fff00113  addi    sp, x0, -1
0x0238: 0820c863  blt     ra, sp, +144
0x023c: 00120213  addi    tp, tp, 1
0x0240: 00200293  addi    t0, x0, 2
0x0244: fe5214e3  bne     tp, t0, -24
0x0248: 01300193  addi    gp, x0, 19
0x024c: 00000213  addi    tp, x0, 0
0x0250: 00000093  addi    ra, x0, 0
0x0254: 00000013  addi    x0, x0, 0
0x0258: fff00113  addi    sp, x0, -1
0x025c: 00000013  addi    x0, x0, 0
0x0260: 0620c463  blt     ra, sp, +104
0x0264: 00120213  addi    tp, tp, 1
0x0268: 00200293  addi    t0, x0, 2
0x026c: fe5212e3  bne     tp, t0, -28
0x0270: 01400193  addi    gp, x0, 20
0x0274: 00000213  addi    tp, x0, 0
0x0278: 00000093  addi    ra, x0, 0
0x027c: 00000013  addi    x0, x0, 0
0x0280: 00000013  addi    x0, x0, 0
0x0284: fff00113  addi    sp, x0, -1
0x0288: 0420c063  blt     ra, sp, +64
0x028c: 00120213  addi    tp, tp, 1
0x0290: 00200293  addi    t0, x0, 2
0x0294: fe5212e3  bne     tp, t0, -28
0x0298: 00100093  addi    ra, x0, 1
0x029c: 00104a63  blt     x0, ra, +20
0x02a0: 00108093  addi    ra, ra, 1
0x02a4: 00108093  addi    ra, ra, 1
0x02a8: 00108093  addi    ra, ra, 1
0x02ac: 00108093  addi    ra, ra, 1
0x02b0: 00108093  addi    ra, ra, 1
0x02b4: 00108093  addi    ra, ra, 1
0x02b8: 00300e93  addi    t4, x0, 3
0x02bc: 01500193  addi    gp, x0, 21
0x02c0: 01d09463  bne     ra, t4, +8
0x02c4: 00301863  bne     x0, gp, +16
0x02c8: 00100d13  addi    s10, x0, 1
0x02cc: 00000d93  addi    s11, x0, 0
0x02d0: 0000006f  j       0              # halt loop
0x02d4: 00100d13  addi    s10, x0, 1
0x02d8: 00100d93  addi    s11, x0, 1
0x02dc: 0000006f  j       0              # halt loop
```

### inst_bltu  \[FAIL ❌（超时）\]

- **ROM 行数：** 242 行（含 NOP 填充），有效指令 197 条
- **指令分布：** ADDI×111, BLTU×27, BNE×31, JAL×2, LUI×26

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 00100113  addi    sp, x0, 1
0x0014: 0020e663  bltu    ra, sp, +12
0x0018: 2e301263  bne     x0, gp, +740
0x001c: 00301663  bne     x0, gp, +12
0x0020: fe20eee3  bltu    ra, sp, -4
0x0024: 2c301c63  bne     x0, gp, +728
0x0028: 00300193  addi    gp, x0, 3
0x002c: ffe00093  addi    ra, x0, -2
0x0030: fff00113  addi    sp, x0, -1
0x0034: 0020e663  bltu    ra, sp, +12
0x0038: 2c301263  bne     x0, gp, +708
0x003c: 00301663  bne     x0, gp, +12
0x0040: fe20eee3  bltu    ra, sp, -4
0x0044: 2a301c63  bne     x0, gp, +696
0x0048: 00400193  addi    gp, x0, 4
0x004c: 00000093  addi    ra, x0, 0
0x0050: fff00113  addi    sp, x0, -1
0x0054: 0020e663  bltu    ra, sp, +12
0x0058: 2a301263  bne     x0, gp, +676
0x005c: 00301663  bne     x0, gp, +12
0x0060: fe20eee3  bltu    ra, sp, -4
0x0064: 28301c63  bne     x0, gp, +664
0x0068: 00500193  addi    gp, x0, 5
0x006c: 00100093  addi    ra, x0, 1
0x0070: 00000113  addi    sp, x0, 0
0x0074: 0020e463  bltu    ra, sp, +8
0x0078: 00301463  bne     x0, gp, +8
0x007c: 28301063  bne     x0, gp, +640
0x0080: fe20eee3  bltu    ra, sp, -4
0x0084: 00600193  addi    gp, x0, 6
0x0088: fff00093  addi    ra, x0, -1
0x008c: ffe00113  addi    sp, x0, -2
0x0090: 0020e463  bltu    ra, sp, +8
0x0094: 00301463  bne     x0, gp, +8
0x0098: 26301263  bne     x0, gp, +612
0x009c: fe20eee3  bltu    ra, sp, -4
0x00a0: 00700193  addi    gp, x0, 7
0x00a4: fff00093  addi    ra, x0, -1
0x00a8: 00000113  addi    sp, x0, 0
0x00ac: 0020e463  bltu    ra, sp, +8
0x00b0: 00301463  bne     x0, gp, +8
0x00b4: 24301463  bne     x0, gp, +584
0x00b8: fe20eee3  bltu    ra, sp, -4
0x00bc: 00800193  addi    gp, x0, 8
0x00c0: 800000b7  lui     ra, 0x80000
0x00c4: 80000137  lui     sp, 0x80000
0x00c8: fff10113  addi    sp, sp, -1
0x00cc: 0020e463  bltu    ra, sp, +8
0x00d0: 00301463  bne     x0, gp, +8
0x00d4: 22301463  bne     x0, gp, +552
0x00d8: fe20eee3  bltu    ra, sp, -4
0x00dc: 00900193  addi    gp, x0, 9
0x00e0: 00000213  addi    tp, x0, 0
0x00e4: f00000b7  lui     ra, 0xf0000
0x00e8: f0000137  lui     sp, 0xf0000
0x00ec: fff10113  addi    sp, sp, -1
0x00f0: 2020e663  bltu    ra, sp, +524
0x00f4: 00120213  addi    tp, tp, 1
0x00f8: 00200293  addi    t0, x0, 2
0x00fc: fe5214e3  bne     tp, t0, -24
0x0100: 00a00193  addi    gp, x0, 10
0x0104: 00000213  addi    tp, x0, 0
0x0108: f00000b7  lui     ra, 0xf0000
0x010c: f0000137  lui     sp, 0xf0000
0x0110: fff10113  addi    sp, sp, -1
0x0114: 00000013  addi    x0, x0, 0
0x0118: 1e20e263  bltu    ra, sp, +484
0x011c: 00120213  addi    tp, tp, 1
0x0120: 00200293  addi    t0, x0, 2
0x0124: fe5212e3  bne     tp, t0, -28
0x0128: 00b00193  addi    gp, x0, 11
0x012c: 00000213  addi    tp, x0, 0
0x0130: f00000b7  lui     ra, 0xf0000
0x0134: f0000137  lui     sp, 0xf0000
0x0138: fff10113  addi    sp, sp, -1
0x013c: 00000013  addi    x0, x0, 0
0x0140: 00000013  addi    x0, x0, 0
0x0144: 1a20ec63  bltu    ra, sp, +440
0x0148: 00120213  addi    tp, tp, 1
0x014c: 00200293  addi    t0, x0, 2
0x0150: fe5210e3  bne     tp, t0, -32
0x0154: 00c00193  addi    gp, x0, 12
0x0158: 00000213  addi    tp, x0, 0
0x015c: f00000b7  lui     ra, 0xf0000
0x0160: 00000013  addi    x0, x0, 0
0x0164: f0000137  lui     sp, 0xf0000
0x0168: fff10113  addi    sp, sp, -1
0x016c: 1820e863  bltu    ra, sp, +400
0x0170: 00120213  addi    tp, tp, 1
0x0174: 00200293  addi    t0, x0, 2
0x0178: fe5212e3  bne     tp, t0, -28
0x017c: 00d00193  addi    gp, x0, 13
0x0180: 00000213  addi    tp, x0, 0
0x0184: f00000b7  lui     ra, 0xf0000
0x0188: 00000013  addi    x0, x0, 0
0x018c: f0000137  lui     sp, 0xf0000
0x0190: fff10113  addi    sp, sp, -1
0x0194: 00000013  addi    x0, x0, 0
0x0198: 1620e263  bltu    ra, sp, +356
0x019c: 00120213  addi    tp, tp, 1
0x01a0: 00200293  addi    t0, x0, 2
0x01a4: fe5210e3  bne     tp, t0, -32
0x01a8: 00e00193  addi    gp, x0, 14
0x01ac: 00000213  addi    tp, x0, 0
0x01b0: f00000b7  lui     ra, 0xf0000
0x01b4: 00000013  addi    x0, x0, 0
0x01b8: 00000013  addi    x0, x0, 0
0x01bc: f0000137  lui     sp, 0xf0000
0x01c0: fff10113  addi    sp, sp, -1
0x01c4: 1220ec63  bltu    ra, sp, +312
0x01c8: 00120213  addi    tp, tp, 1
0x01cc: 00200293  addi    t0, x0, 2
0x01d0: fe5210e3  bne     tp, t0, -32
0x01d4: 00f00193  addi    gp, x0, 15
0x01d8: 00000213  addi    tp, x0, 0
0x01dc: f00000b7  lui     ra, 0xf0000
0x01e0: f0000137  lui     sp, 0xf0000
0x01e4: fff10113  addi    sp, sp, -1
0x01e8: 1020ea63  bltu    ra, sp, +276
0x01ec: 00120213  addi    tp, tp, 1
0x01f0: 00200293  addi    t0, x0, 2
0x01f4: fe5214e3  bne     tp, t0, -24
0x01f8: 01000193  addi    gp, x0, 16
0x01fc: 00000213  addi    tp, x0, 0
0x0200: f00000b7  lui     ra, 0xf0000
0x0204: f0000137  lui     sp, 0xf0000
0x0208: fff10113  addi    sp, sp, -1
0x020c: 00000013  addi    x0, x0, 0
0x0210: 0e20e663  bltu    ra, sp, +236
0x0214: 00120213  addi    tp, tp, 1
0x0218: 00200293  addi    t0, x0, 2
0x021c: fe5212e3  bne     tp, t0, -28
0x0220: 01100193  addi    gp, x0, 17
0x0224: 00000213  addi    tp, x0, 0
0x0228: f00000b7  lui     ra, 0xf0000
0x022c: f0000137  lui     sp, 0xf0000
0x0230: fff10113  addi    sp, sp, -1
0x0234: 00000013  addi    x0, x0, 0
0x0238: 00000013  addi    x0, x0, 0
0x023c: 0c20e063  bltu    ra, sp, +192
0x0240: 00120213  addi    tp, tp, 1
0x0244: 00200293  addi    t0, x0, 2
0x0248: fe5210e3  bne     tp, t0, -32
0x024c: 01200193  addi    gp, x0, 18
0x0250: 00000213  addi    tp, x0, 0
0x0254: f00000b7  lui     ra, 0xf0000
0x0258: 00000013  addi    x0, x0, 0
0x025c: f0000137  lui     sp, 0xf0000
0x0260: fff10113  addi    sp, sp, -1
0x0264: 0820ec63  bltu    ra, sp, +152
0x0268: 00120213  addi    tp, tp, 1
0x026c: 00200293  addi    t0, x0, 2
0x0270: fe5212e3  bne     tp, t0, -28
0x0274: 01300193  addi    gp, x0, 19
0x0278: 00000213  addi    tp, x0, 0
0x027c: f00000b7  lui     ra, 0xf0000
0x0280: 00000013  addi    x0, x0, 0
0x0284: f0000137  lui     sp, 0xf0000
0x0288: fff10113  addi    sp, sp, -1
0x028c: 00000013  addi    x0, x0, 0
0x0290: 0620e663  bltu    ra, sp, +108
0x0294: 00120213  addi    tp, tp, 1
0x0298: 00200293  addi    t0, x0, 2
0x029c: fe5210e3  bne     tp, t0, -32
0x02a0: 01400193  addi    gp, x0, 20
0x02a4: 00000213  addi    tp, x0, 0
0x02a8: f00000b7  lui     ra, 0xf0000
0x02ac: 00000013  addi    x0, x0, 0
0x02b0: 00000013  addi    x0, x0, 0
0x02b4: f0000137  lui     sp, 0xf0000
0x02b8: fff10113  addi    sp, sp, -1
0x02bc: 0420e063  bltu    ra, sp, +64
0x02c0: 00120213  addi    tp, tp, 1
0x02c4: 00200293  addi    t0, x0, 2
0x02c8: fe5210e3  bne     tp, t0, -32
0x02cc: 00100093  addi    ra, x0, 1
0x02d0: 00106a63  bltu    x0, ra, +20
0x02d4: 00108093  addi    ra, ra, 1
0x02d8: 00108093  addi    ra, ra, 1
0x02dc: 00108093  addi    ra, ra, 1
0x02e0: 00108093  addi    ra, ra, 1
0x02e4: 00108093  addi    ra, ra, 1
0x02e8: 00108093  addi    ra, ra, 1
0x02ec: 00300e93  addi    t4, x0, 3
0x02f0: 01500193  addi    gp, x0, 21
0x02f4: 01d09463  bne     ra, t4, +8
0x02f8: 00301863  bne     x0, gp, +16
0x02fc: 00100d13  addi    s10, x0, 1
0x0300: 00000d93  addi    s11, x0, 0
0x0304: 0000006f  j       0              # halt loop
0x0308: 00100d13  addi    s10, x0, 1
0x030c: 00100d93  addi    s11, x0, 1
0x0310: 0000006f  j       0              # halt loop
```

### inst_bne  \[PASS ✅\]

- **ROM 行数：** 226 行（含 NOP 填充），有效指令 185 条
- **指令分布：** ADDI×124, BNE×59, JAL×2

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 00100113  addi    sp, x0, 1
0x0014: 00209663  bne     ra, sp, +12
0x0018: 2a301a63  bne     x0, gp, +692
0x001c: 00301663  bne     x0, gp, +12
0x0020: fe209ee3  bne     ra, sp, -4
0x0024: 2a301463  bne     x0, gp, +680
0x0028: 00300193  addi    gp, x0, 3
0x002c: 00100093  addi    ra, x0, 1
0x0030: 00000113  addi    sp, x0, 0
0x0034: 00209663  bne     ra, sp, +12
0x0038: 28301a63  bne     x0, gp, +660
0x003c: 00301663  bne     x0, gp, +12
0x0040: fe209ee3  bne     ra, sp, -4
0x0044: 28301463  bne     x0, gp, +648
0x0048: 00400193  addi    gp, x0, 4
0x004c: fff00093  addi    ra, x0, -1
0x0050: 00100113  addi    sp, x0, 1
0x0054: 00209663  bne     ra, sp, +12
0x0058: 26301a63  bne     x0, gp, +628
0x005c: 00301663  bne     x0, gp, +12
0x0060: fe209ee3  bne     ra, sp, -4
0x0064: 26301463  bne     x0, gp, +616
0x0068: 00500193  addi    gp, x0, 5
0x006c: 00100093  addi    ra, x0, 1
0x0070: fff00113  addi    sp, x0, -1
0x0074: 00209663  bne     ra, sp, +12
0x0078: 24301a63  bne     x0, gp, +596
0x007c: 00301663  bne     x0, gp, +12
0x0080: fe209ee3  bne     ra, sp, -4
0x0084: 24301463  bne     x0, gp, +584
0x0088: 00600193  addi    gp, x0, 6
0x008c: 00000093  addi    ra, x0, 0
0x0090: 00000113  addi    sp, x0, 0
0x0094: 00209463  bne     ra, sp, +8
0x0098: 00301463  bne     x0, gp, +8
0x009c: 22301863  bne     x0, gp, +560
0x00a0: fe209ee3  bne     ra, sp, -4
0x00a4: 00700193  addi    gp, x0, 7
0x00a8: 00100093  addi    ra, x0, 1
0x00ac: 00100113  addi    sp, x0, 1
0x00b0: 00209463  bne     ra, sp, +8
0x00b4: 00301463  bne     x0, gp, +8
0x00b8: 20301a63  bne     x0, gp, +532
0x00bc: fe209ee3  bne     ra, sp, -4
0x00c0: 00800193  addi    gp, x0, 8
0x00c4: fff00093  addi    ra, x0, -1
0x00c8: fff00113  addi    sp, x0, -1
0x00cc: 00209463  bne     ra, sp, +8
0x00d0: 00301463  bne     x0, gp, +8
0x00d4: 1e301c63  bne     x0, gp, +504
0x00d8: fe209ee3  bne     ra, sp, -4
0x00dc: 00900193  addi    gp, x0, 9
0x00e0: 00000213  addi    tp, x0, 0
0x00e4: 00000093  addi    ra, x0, 0
0x00e8: 00000113  addi    sp, x0, 0
0x00ec: 1e209063  bne     ra, sp, +480
0x00f0: 00120213  addi    tp, tp, 1
0x00f4: 00200293  addi    t0, x0, 2
0x00f8: fe5216e3  bne     tp, t0, -20
0x00fc: 00a00193  addi    gp, x0, 10
0x0100: 00000213  addi    tp, x0, 0
0x0104: 00000093  addi    ra, x0, 0
0x0108: 00000113  addi    sp, x0, 0
0x010c: 00000013  addi    x0, x0, 0
0x0110: 1a209e63  bne     ra, sp, +444
0x0114: 00120213  addi    tp, tp, 1
0x0118: 00200293  addi    t0, x0, 2
0x011c: fe5214e3  bne     tp, t0, -24
0x0120: 00b00193  addi    gp, x0, 11
0x0124: 00000213  addi    tp, x0, 0
0x0128: 00000093  addi    ra, x0, 0
0x012c: 00000113  addi    sp, x0, 0
0x0130: 00000013  addi    x0, x0, 0
0x0134: 00000013  addi    x0, x0, 0
0x0138: 18209a63  bne     ra, sp, +404
0x013c: 00120213  addi    tp, tp, 1
0x0140: 00200293  addi    t0, x0, 2
0x0144: fe5212e3  bne     tp, t0, -28
0x0148: 00c00193  addi    gp, x0, 12
0x014c: 00000213  addi    tp, x0, 0
0x0150: 00000093  addi    ra, x0, 0
0x0154: 00000013  addi    x0, x0, 0
0x0158: 00000113  addi    sp, x0, 0
0x015c: 16209863  bne     ra, sp, +368
0x0160: 00120213  addi    tp, tp, 1
0x0164: 00200293  addi    t0, x0, 2
0x0168: fe5214e3  bne     tp, t0, -24
0x016c: 00d00193  addi    gp, x0, 13
0x0170: 00000213  addi    tp, x0, 0
0x0174: 00000093  addi    ra, x0, 0
0x0178: 00000013  addi    x0, x0, 0
0x017c: 00000113  addi    sp, x0, 0
0x0180: 00000013  addi    x0, x0, 0
0x0184: 14209463  bne     ra, sp, +328
0x0188: 00120213  addi    tp, tp, 1
0x018c: 00200293  addi    t0, x0, 2
0x0190: fe5212e3  bne     tp, t0, -28
0x0194: 00e00193  addi    gp, x0, 14
0x0198: 00000213  addi    tp, x0, 0
0x019c: 00000093  addi    ra, x0, 0
0x01a0: 00000013  addi    x0, x0, 0
0x01a4: 00000013  addi    x0, x0, 0
0x01a8: 00000113  addi    sp, x0, 0
0x01ac: 12209063  bne     ra, sp, +288
0x01b0: 00120213  addi    tp, tp, 1
0x01b4: 00200293  addi    t0, x0, 2
0x01b8: fe5212e3  bne     tp, t0, -28
0x01bc: 00f00193  addi    gp, x0, 15
0x01c0: 00000213  addi    tp, x0, 0
0x01c4: 00000093  addi    ra, x0, 0
0x01c8: 00000113  addi    sp, x0, 0
0x01cc: 10209063  bne     ra, sp, +256
0x01d0: 00120213  addi    tp, tp, 1
0x01d4: 00200293  addi    t0, x0, 2
0x01d8: fe5216e3  bne     tp, t0, -20
0x01dc: 01000193  addi    gp, x0, 16
0x01e0: 00000213  addi    tp, x0, 0
0x01e4: 00000093  addi    ra, x0, 0
0x01e8: 00000113  addi    sp, x0, 0
0x01ec: 00000013  addi    x0, x0, 0
0x01f0: 0c209e63  bne     ra, sp, +220
0x01f4: 00120213  addi    tp, tp, 1
0x01f8: 00200293  addi    t0, x0, 2
0x01fc: fe5214e3  bne     tp, t0, -24
0x0200: 01100193  addi    gp, x0, 17
0x0204: 00000213  addi    tp, x0, 0
0x0208: 00000093  addi    ra, x0, 0
0x020c: 00000113  addi    sp, x0, 0
0x0210: 00000013  addi    x0, x0, 0
0x0214: 00000013  addi    x0, x0, 0
0x0218: 0a209a63  bne     ra, sp, +180
0x021c: 00120213  addi    tp, tp, 1
0x0220: 00200293  addi    t0, x0, 2
0x0224: fe5212e3  bne     tp, t0, -28
0x0228: 01200193  addi    gp, x0, 18
0x022c: 00000213  addi    tp, x0, 0
0x0230: 00000093  addi    ra, x0, 0
0x0234: 00000013  addi    x0, x0, 0
0x0238: 00000113  addi    sp, x0, 0
0x023c: 08209863  bne     ra, sp, +144
0x0240: 00120213  addi    tp, tp, 1
0x0244: 00200293  addi    t0, x0, 2
0x0248: fe5214e3  bne     tp, t0, -24
0x024c: 01300193  addi    gp, x0, 19
0x0250: 00000213  addi    tp, x0, 0
0x0254: 00000093  addi    ra, x0, 0
0x0258: 00000013  addi    x0, x0, 0
0x025c: 00000113  addi    sp, x0, 0
0x0260: 00000013  addi    x0, x0, 0
0x0264: 06209463  bne     ra, sp, +104
0x0268: 00120213  addi    tp, tp, 1
0x026c: 00200293  addi    t0, x0, 2
0x0270: fe5212e3  bne     tp, t0, -28
0x0274: 01400193  addi    gp, x0, 20
0x0278: 00000213  addi    tp, x0, 0
0x027c: 00000093  addi    ra, x0, 0
0x0280: 00000013  addi    x0, x0, 0
0x0284: 00000013  addi    x0, x0, 0
0x0288: 00000113  addi    sp, x0, 0
0x028c: 04209063  bne     ra, sp, +64
0x0290: 00120213  addi    tp, tp, 1
0x0294: 00200293  addi    t0, x0, 2
0x0298: fe5212e3  bne     tp, t0, -28
0x029c: 00100093  addi    ra, x0, 1
0x02a0: 00009a63  bne     ra, x0, +20
0x02a4: 00108093  addi    ra, ra, 1
0x02a8: 00108093  addi    ra, ra, 1
0x02ac: 00108093  addi    ra, ra, 1
0x02b0: 00108093  addi    ra, ra, 1
0x02b4: 00108093  addi    ra, ra, 1
0x02b8: 00108093  addi    ra, ra, 1
0x02bc: 00300e93  addi    t4, x0, 3
0x02c0: 01500193  addi    gp, x0, 21
0x02c4: 01d09463  bne     ra, t4, +8
0x02c8: 00301863  bne     x0, gp, +16
0x02cc: 00100d13  addi    s10, x0, 1
0x02d0: 00000d93  addi    s11, x0, 0
0x02d4: 0000006f  j       0              # halt loop
0x02d8: 00100d13  addi    s10, x0, 1
0x02dc: 00100d93  addi    s11, x0, 1
0x02e0: 0000006f  j       0              # halt loop
```

### inst_div  \[PASS ✅\]

- **ROM 行数：** 98 行（含 NOP 填充），有效指令 63 条
- **指令分布：** ADDI×42, BNE×10, JAL×2, XOR×9

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 01400093  addi    ra, x0, 20
0x000c: 00600113  addi    sp, x0, 6
0x0010: 0220cf33  xor     t5, ra, sp
0x0014: 00300e93  addi    t4, x0, 3
0x0018: 00200193  addi    gp, x0, 2
0x001c: 0ddf1463  bne     t5, t4, +200
0x0020: fec00093  addi    ra, x0, -20
0x0024: 00600113  addi    sp, x0, 6
0x0028: 0220cf33  xor     t5, ra, sp
0x002c: ffd00e93  addi    t4, x0, -3
0x0030: 00300193  addi    gp, x0, 3
0x0034: 0bdf1863  bne     t5, t4, +176
0x0038: 01400093  addi    ra, x0, 20
0x003c: ffa00113  addi    sp, x0, -6
0x0040: 0220cf33  xor     t5, ra, sp
0x0044: ffd00e93  addi    t4, x0, -3
0x0048: 00400193  addi    gp, x0, 4
0x004c: 09df1c63  bne     t5, t4, +152
0x0050: fec00093  addi    ra, x0, -20
0x0054: ffa00113  addi    sp, x0, -6
0x0058: 0220cf33  xor     t5, ra, sp
0x005c: 00300e93  addi    t4, x0, 3
0x0060: 00500193  addi    gp, x0, 5
0x0064: 09df1063  bne     t5, t4, +128
0x0068: 00000093  addi    ra, x0, 0
0x006c: 00100113  addi    sp, x0, 1
0x0070: 0220cf33  xor     t5, ra, sp
0x0074: 00000e93  addi    t4, x0, 0
0x0078: 00600193  addi    gp, x0, 6
0x007c: 07df1463  bne     t5, t4, +104
0x0080: 00000093  addi    ra, x0, 0
0x0084: fff00113  addi    sp, x0, -1
0x0088: 0220cf33  xor     t5, ra, sp
0x008c: 00000e93  addi    t4, x0, 0
0x0090: 00700193  addi    gp, x0, 7
0x0094: 05df1863  bne     t5, t4, +80
0x0098: 00000093  addi    ra, x0, 0
0x009c: 00000113  addi    sp, x0, 0
0x00a0: 0220cf33  xor     t5, ra, sp
0x00a4: fff00e93  addi    t4, x0, -1
0x00a8: 00800193  addi    gp, x0, 8
0x00ac: 03df1c63  bne     t5, t4, +56
0x00b0: 00100093  addi    ra, x0, 1
0x00b4: 00000113  addi    sp, x0, 0
0x00b8: 0220cf33  xor     t5, ra, sp
0x00bc: fff00e93  addi    t4, x0, -1
0x00c0: 00900193  addi    gp, x0, 9
0x00c4: 03df1063  bne     t5, t4, +32
0x00c8: 00000093  addi    ra, x0, 0
0x00cc: 00000113  addi    sp, x0, 0
0x00d0: 0220cf33  xor     t5, ra, sp
0x00d4: fff00e93  addi    t4, x0, -1
0x00d8: 00a00193  addi    gp, x0, 10
0x00dc: 01df1463  bne     t5, t4, +8
0x00e0: 00301863  bne     x0, gp, +16
0x00e4: 00100d13  addi    s10, x0, 1
0x00e8: 00000d93  addi    s11, x0, 0
0x00ec: 0000006f  j       0              # halt loop
0x00f0: 00100d13  addi    s10, x0, 1
0x00f4: 00100d93  addi    s11, x0, 1
0x00f8: 0000006f  j       0              # halt loop
```

### inst_divu  \[PASS ✅\]

- **ROM 行数：** 98 行（含 NOP 填充），有效指令 64 条
- **指令分布：** ADDI×38, BNE×10, JAL×2, LUI×5, SRA×9

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 01400093  addi    ra, x0, 20
0x000c: 00600113  addi    sp, x0, 6
0x0010: 0220df33  sra     t5, ra, sp
0x0014: 00300e93  addi    t4, x0, 3
0x0018: 00200193  addi    gp, x0, 2
0x001c: 0ddf1663  bne     t5, t4, +204
0x0020: fec00093  addi    ra, x0, -20
0x0024: 00600113  addi    sp, x0, 6
0x0028: 0220df33  sra     t5, ra, sp
0x002c: 2aaabeb7  lui     t4, 0x2aaab
0x0030: aa7e8e93  addi    t4, t4, -1369
0x0034: 00300193  addi    gp, x0, 3
0x0038: 0bdf1863  bne     t5, t4, +176
0x003c: 01400093  addi    ra, x0, 20
0x0040: ffa00113  addi    sp, x0, -6
0x0044: 0220df33  sra     t5, ra, sp
0x0048: 00000e93  addi    t4, x0, 0
0x004c: 00400193  addi    gp, x0, 4
0x0050: 09df1c63  bne     t5, t4, +152
0x0054: fec00093  addi    ra, x0, -20
0x0058: ffa00113  addi    sp, x0, -6
0x005c: 0220df33  sra     t5, ra, sp
0x0060: 00000e93  addi    t4, x0, 0
0x0064: 00500193  addi    gp, x0, 5
0x0068: 09df1063  bne     t5, t4, +128
0x006c: 800000b7  lui     ra, 0x80000
0x0070: 00100113  addi    sp, x0, 1
0x0074: 0220df33  sra     t5, ra, sp
0x0078: 80000eb7  lui     t4, 0x80000
0x007c: 00600193  addi    gp, x0, 6
0x0080: 07df1463  bne     t5, t4, +104
0x0084: 800000b7  lui     ra, 0x80000
0x0088: fff00113  addi    sp, x0, -1
0x008c: 0220df33  sra     t5, ra, sp
0x0090: 00000e93  addi    t4, x0, 0
0x0094: 00700193  addi    gp, x0, 7
0x0098: 05df1863  bne     t5, t4, +80
0x009c: 800000b7  lui     ra, 0x80000
0x00a0: 00000113  addi    sp, x0, 0
0x00a4: 0220df33  sra     t5, ra, sp
0x00a8: fff00e93  addi    t4, x0, -1
0x00ac: 00800193  addi    gp, x0, 8
0x00b0: 03df1c63  bne     t5, t4, +56
0x00b4: 00100093  addi    ra, x0, 1
0x00b8: 00000113  addi    sp, x0, 0
0x00bc: 0220df33  sra     t5, ra, sp
0x00c0: fff00e93  addi    t4, x0, -1
0x00c4: 00900193  addi    gp, x0, 9
0x00c8: 03df1063  bne     t5, t4, +32
0x00cc: 00000093  addi    ra, x0, 0
0x00d0: 00000113  addi    sp, x0, 0
0x00d4: 0220df33  sra     t5, ra, sp
0x00d8: fff00e93  addi    t4, x0, -1
0x00dc: 00a00193  addi    gp, x0, 10
0x00e0: 01df1463  bne     t5, t4, +8
0x00e4: 00301863  bne     x0, gp, +16
0x00e8: 00100d13  addi    s10, x0, 1
0x00ec: 00000d93  addi    s11, x0, 0
0x00f0: 0000006f  j       0              # halt loop
0x00f4: 00100d13  addi    s10, x0, 1
0x00f8: 00100d93  addi    s11, x0, 1
0x00fc: 0000006f  j       0              # halt loop
```

### inst_jal  \[FAIL ❌（超时）\]

- **ROM 行数：** 66 行（含 NOP 填充），有效指令 29 条
- **指令分布：** ADDI×20, AUIPC×1, BNE×3, JAL×5

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000093  addi    ra, x0, 0
0x0010: 0100026f  jal     tp, +16
0x0014: 00000013  addi    x0, x0, 0
0x0018: 00000013  addi    x0, x0, 0
0x001c: 0400006f  jal     x0, +64
0x0020: 00000117  auipc   sp, 0x00000
0x0024: ff410113  addi    sp, sp, -12
0x0028: 02411a63  bne     sp, tp, +52
0x002c: 00100093  addi    ra, x0, 1
0x0030: 0140006f  jal     x0, +20
0x0034: 00108093  addi    ra, ra, 1
0x0038: 00108093  addi    ra, ra, 1
0x003c: 00108093  addi    ra, ra, 1
0x0040: 00108093  addi    ra, ra, 1
0x0044: 00108093  addi    ra, ra, 1
0x0048: 00108093  addi    ra, ra, 1
0x004c: 00300e93  addi    t4, x0, 3
0x0050: 00300193  addi    gp, x0, 3
0x0054: 01d09463  bne     ra, t4, +8
0x0058: 00301863  bne     x0, gp, +16
0x005c: 00100d13  addi    s10, x0, 1
0x0060: 00000d93  addi    s11, x0, 0
0x0064: 0000006f  j       0              # halt loop
0x0068: 00100d13  addi    s10, x0, 1
0x006c: 00100d93  addi    s11, x0, 1
0x0070: 0000006f  j       0              # halt loop
```

### inst_jalr  \[FAIL ❌（超时）\]

- **ROM 行数：** 98 行（含 NOP 填充），有效指令 61 条
- **指令分布：** ADDI×38, AUIPC×6, BNE×9, JAL×3, JALR×5

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00200193  addi    gp, x0, 2
0x000c: 00000293  addi    t0, x0, 0
0x0010: 00000317  auipc   t1, 0x00000
0x0014: 01030313  addi    t1, t1, 16
0x0018: 000302e7  jalr    t0, t1, 0
0x001c: 0c00006f  jal     x0, +192
0x0020: 00000317  auipc   t1, 0x00000
0x0024: ffc30313  addi    t1, t1, -4
0x0028: 0a629a63  bne     t0, t1, +180
0x002c: 00400193  addi    gp, x0, 4
0x0030: 00000213  addi    tp, x0, 0
0x0034: 00000317  auipc   t1, 0x00000
0x0038: 01030313  addi    t1, t1, 16
0x003c: 000309e7  jalr    s3, t1, 0
0x0040: 08301e63  bne     x0, gp, +156
0x0044: 00120213  addi    tp, tp, 1
0x0048: 00200293  addi    t0, x0, 2
0x004c: fe5214e3  bne     tp, t0, -24
0x0050: 00500193  addi    gp, x0, 5
0x0054: 00000213  addi    tp, x0, 0
0x0058: 00000317  auipc   t1, 0x00000
0x005c: 01430313  addi    t1, t1, 20
0x0060: 00000013  addi    x0, x0, 0
0x0064: 000309e7  jalr    s3, t1, 0
0x0068: 06301a63  bne     x0, gp, +116
0x006c: 00120213  addi    tp, tp, 1
0x0070: 00200293  addi    t0, x0, 2
0x0074: fe5212e3  bne     tp, t0, -28
0x0078: 00600193  addi    gp, x0, 6
0x007c: 00000213  addi    tp, x0, 0
0x0080: 00000317  auipc   t1, 0x00000
0x0084: 01830313  addi    t1, t1, 24
0x0088: 00000013  addi    x0, x0, 0
0x008c: 00000013  addi    x0, x0, 0
0x0090: 000309e7  jalr    s3, t1, 0
0x0094: 04301463  bne     x0, gp, +72
0x0098: 00120213  addi    tp, tp, 1
0x009c: 00200293  addi    t0, x0, 2
0x00a0: fe5210e3  bne     tp, t0, -32
0x00a4: 00100293  addi    t0, x0, 1
0x00a8: 00000317  auipc   t1, 0x00000
0x00ac: 01c30313  addi    t1, t1, 28
0x00b0: ffc30067  jalr    x0, t1, -4
0x00b4: 00128293  addi    t0, t0, 1
0x00b8: 00128293  addi    t0, t0, 1
0x00bc: 00128293  addi    t0, t0, 1
0x00c0: 00128293  addi    t0, t0, 1
0x00c4: 00128293  addi    t0, t0, 1
0x00c8: 00128293  addi    t0, t0, 1
0x00cc: 00400e93  addi    t4, x0, 4
0x00d0: 00700193  addi    gp, x0, 7
0x00d4: 01d29463  bne     t0, t4, +8
0x00d8: 00301863  bne     x0, gp, +16
0x00dc: 00100d13  addi    s10, x0, 1
0x00e0: 00000d93  addi    s11, x0, 0
0x00e4: 0000006f  j       0              # halt loop
0x00e8: 00100d13  addi    s10, x0, 1
0x00ec: 00100d93  addi    s11, x0, 1
0x00f0: 0000006f  j       0              # halt loop
```

### inst_lui  \[FAIL ❌（超时）\]

- **ROM 行数：** 66 行（含 NOP 填充），有效指令 32 条
- **指令分布：** ADDI×16, BNE×6, JAL×2, LUI×5, SRAI×3

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 000000b7  lui     ra, 0x00000
0x000c: 00000e93  addi    t4, x0, 0
0x0010: 00200193  addi    gp, x0, 2
0x0014: 05d09a63  bne     ra, t4, +84
0x0018: fffff0b7  lui     ra, 0xfffff
0x001c: 4010d093  srai    ra, ra, 1
0x0020: 80000e93  addi    t4, x0, -2048
0x0024: 00300193  addi    gp, x0, 3
0x0028: 05d09063  bne     ra, t4, +64
0x002c: 7ffff0b7  lui     ra, 0x7ffff
0x0030: 4140d093  srai    ra, ra, 20
0x0034: 7ff00e93  addi    t4, x0, 2047
0x0038: 00400193  addi    gp, x0, 4
0x003c: 03d09663  bne     ra, t4, +44
0x0040: 800000b7  lui     ra, 0x80000
0x0044: 4140d093  srai    ra, ra, 20
0x0048: 80000e93  addi    t4, x0, -2048
0x004c: 00500193  addi    gp, x0, 5
0x0050: 01d09c63  bne     ra, t4, +24
0x0054: 80000037  lui     x0, 0x80000
0x0058: 00000e93  addi    t4, x0, 0
0x005c: 00600193  addi    gp, x0, 6
0x0060: 01d01463  bne     x0, t4, +8
0x0064: 00301863  bne     x0, gp, +16
0x0068: 00100d13  addi    s10, x0, 1
0x006c: 00000d93  addi    s11, x0, 0
0x0070: 0000006f  j       0              # halt loop
0x0074: 00100d13  addi    s10, x0, 1
0x0078: 00100d93  addi    s11, x0, 1
0x007c: 0000006f  j       0              # halt loop
```

### inst_ori  \[PASS ✅\]

- **ROM 行数：** 162 行（含 NOP 填充），有效指令 127 条
- **指令分布：** ADDI×71, BNE×20, JAL×2, LUI×21, ORI×13

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: ff0100b7  lui     ra, 0xff010
0x000c: f0008093  addi    ra, ra, -256
0x0010: f0f0ef13  ori     t5, ra, -241
0x0014: f0f00e93  addi    t4, x0, -241
0x0018: 00200193  addi    gp, x0, 2
0x001c: 1ddf1463  bne     t5, t4, +456
0x0020: 0ff010b7  lui     ra, 0x0ff01
0x0024: ff008093  addi    ra, ra, -16
0x0028: 0f00ef13  ori     t5, ra, 240
0x002c: 0ff01eb7  lui     t4, 0x0ff01
0x0030: ff0e8e93  addi    t4, t4, -16
0x0034: 00300193  addi    gp, x0, 3
0x0038: 1bdf1663  bne     t5, t4, +428
0x003c: 00ff00b7  lui     ra, 0x00ff0
0x0040: 0ff08093  addi    ra, ra, 255
0x0044: 70f0ef13  ori     t5, ra, 1807
0x0048: 00ff0eb7  lui     t4, 0x00ff0
0x004c: 7ffe8e93  addi    t4, t4, 2047
0x0050: 00400193  addi    gp, x0, 4
0x0054: 19df1863  bne     t5, t4, +400
0x0058: f00ff0b7  lui     ra, 0xf00ff
0x005c: 00f08093  addi    ra, ra, 15
0x0060: 0f00ef13  ori     t5, ra, 240
0x0064: f00ffeb7  lui     t4, 0xf00ff
0x0068: 0ffe8e93  addi    t4, t4, 255
0x006c: 00500193  addi    gp, x0, 5
0x0070: 17df1a63  bne     t5, t4, +372
0x0074: ff0100b7  lui     ra, 0xff010
0x0078: f0008093  addi    ra, ra, -256
0x007c: 0f00e093  ori     ra, ra, 240
0x0080: ff010eb7  lui     t4, 0xff010
0x0084: ff0e8e93  addi    t4, t4, -16
0x0088: 00600193  addi    gp, x0, 6
0x008c: 15d09c63  bne     ra, t4, +344
0x0090: 00000213  addi    tp, x0, 0
0x0094: 0ff010b7  lui     ra, 0x0ff01
0x0098: ff008093  addi    ra, ra, -16
0x009c: 0f00ef13  ori     t5, ra, 240
0x00a0: 000f0313  addi    t1, t5, 0
0x00a4: 00120213  addi    tp, tp, 1
0x00a8: 00200293  addi    t0, x0, 2
0x00ac: fe5214e3  bne     tp, t0, -24
0x00b0: 0ff01eb7  lui     t4, 0x0ff01
0x00b4: ff0e8e93  addi    t4, t4, -16
0x00b8: 00700193  addi    gp, x0, 7
0x00bc: 13d31463  bne     t1, t4, +296
0x00c0: 00000213  addi    tp, x0, 0
0x00c4: 00ff00b7  lui     ra, 0x00ff0
0x00c8: 0ff08093  addi    ra, ra, 255
0x00cc: 70f0ef13  ori     t5, ra, 1807
0x00d0: 00000013  addi    x0, x0, 0
0x00d4: 000f0313  addi    t1, t5, 0
0x00d8: 00120213  addi    tp, tp, 1
0x00dc: 00200293  addi    t0, x0, 2
0x00e0: fe5212e3  bne     tp, t0, -28
0x00e4: 00ff0eb7  lui     t4, 0x00ff0
0x00e8: 7ffe8e93  addi    t4, t4, 2047
0x00ec: 00800193  addi    gp, x0, 8
0x00f0: 0fd31a63  bne     t1, t4, +244
0x00f4: 00000213  addi    tp, x0, 0
0x00f8: f00ff0b7  lui     ra, 0xf00ff
0x00fc: 00f08093  addi    ra, ra, 15
0x0100: 0f00ef13  ori     t5, ra, 240
0x0104: 00000013  addi    x0, x0, 0
0x0108: 00000013  addi    x0, x0, 0
0x010c: 000f0313  addi    t1, t5, 0
0x0110: 00120213  addi    tp, tp, 1
0x0114: 00200293  addi    t0, x0, 2
0x0118: fe5210e3  bne     tp, t0, -32
0x011c: f00ffeb7  lui     t4, 0xf00ff
0x0120: 0ffe8e93  addi    t4, t4, 255
0x0124: 00900193  addi    gp, x0, 9
0x0128: 0bd31e63  bne     t1, t4, +188
0x012c: 00000213  addi    tp, x0, 0
0x0130: 0ff010b7  lui     ra, 0x0ff01
0x0134: ff008093  addi    ra, ra, -16
0x0138: 0f00ef13  ori     t5, ra, 240
0x013c: 00120213  addi    tp, tp, 1
0x0140: 00200293  addi    t0, x0, 2
0x0144: fe5216e3  bne     tp, t0, -20
0x0148: 0ff01eb7  lui     t4, 0x0ff01
0x014c: ff0e8e93  addi    t4, t4, -16
0x0150: 00a00193  addi    gp, x0, 10
0x0154: 09df1863  bne     t5, t4, +144
0x0158: 00000213  addi    tp, x0, 0
0x015c: 00ff00b7  lui     ra, 0x00ff0
0x0160: 0ff08093  addi    ra, ra, 255
0x0164: 00000013  addi    x0, x0, 0
0x0168: f0f0ef13  ori     t5, ra, -241
0x016c: 00120213  addi    tp, tp, 1
0x0170: 00200293  addi    t0, x0, 2
0x0174: fe5214e3  bne     tp, t0, -24
0x0178: fff00e93  addi    t4, x0, -1
0x017c: 00b00193  addi    gp, x0, 11
0x0180: 07df1263  bne     t5, t4, +100
0x0184: 00000213  addi    tp, x0, 0
0x0188: f00ff0b7  lui     ra, 0xf00ff
0x018c: 00f08093  addi    ra, ra, 15
0x0190: 00000013  addi    x0, x0, 0
0x0194: 00000013  addi    x0, x0, 0
0x0198: 0f00ef13  ori     t5, ra, 240
0x019c: 00120213  addi    tp, tp, 1
0x01a0: 00200293  addi    t0, x0, 2
0x01a4: fe5212e3  bne     tp, t0, -28
0x01a8: f00ffeb7  lui     t4, 0xf00ff
0x01ac: 0ffe8e93  addi    t4, t4, 255
0x01b0: 00c00193  addi    gp, x0, 12
0x01b4: 03df1863  bne     t5, t4, +48
0x01b8: 0f006093  ori     ra, x0, 240
0x01bc: 0f000e93  addi    t4, x0, 240
0x01c0: 00d00193  addi    gp, x0, 13
0x01c4: 03d09063  bne     ra, t4, +32
0x01c8: 00ff00b7  lui     ra, 0x00ff0
0x01cc: 0ff08093  addi    ra, ra, 255
0x01d0: 70f0e013  ori     x0, ra, 1807
0x01d4: 00000e93  addi    t4, x0, 0
0x01d8: 00e00193  addi    gp, x0, 14
0x01dc: 01d01463  bne     x0, t4, +8
0x01e0: 00301863  bne     x0, gp, +16
0x01e4: 00100d13  addi    s10, x0, 1
0x01e8: 00000d93  addi    s11, x0, 0
0x01ec: 0000006f  j       0              # halt loop
0x01f0: 00100d13  addi    s10, x0, 1
0x01f4: 00100d93  addi    s11, x0, 1
0x01f8: 0000006f  j       0              # halt loop
```

### inst_rem  \[PASS ✅\]

- **ROM 行数：** 98 行（含 NOP 填充），有效指令 63 条
- **指令分布：** ADDI×42, BNE×10, JAL×2, OR×9

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 01400093  addi    ra, x0, 20
0x000c: 00600113  addi    sp, x0, 6
0x0010: 0220ef33  or      t5, ra, sp
0x0014: 00200e93  addi    t4, x0, 2
0x0018: 00200193  addi    gp, x0, 2
0x001c: 0ddf1463  bne     t5, t4, +200
0x0020: fec00093  addi    ra, x0, -20
0x0024: 00600113  addi    sp, x0, 6
0x0028: 0220ef33  or      t5, ra, sp
0x002c: ffe00e93  addi    t4, x0, -2
0x0030: 00300193  addi    gp, x0, 3
0x0034: 0bdf1863  bne     t5, t4, +176
0x0038: 01400093  addi    ra, x0, 20
0x003c: ffa00113  addi    sp, x0, -6
0x0040: 0220ef33  or      t5, ra, sp
0x0044: 00200e93  addi    t4, x0, 2
0x0048: 00400193  addi    gp, x0, 4
0x004c: 09df1c63  bne     t5, t4, +152
0x0050: fec00093  addi    ra, x0, -20
0x0054: ffa00113  addi    sp, x0, -6
0x0058: 0220ef33  or      t5, ra, sp
0x005c: ffe00e93  addi    t4, x0, -2
0x0060: 00500193  addi    gp, x0, 5
0x0064: 09df1063  bne     t5, t4, +128
0x0068: 00000093  addi    ra, x0, 0
0x006c: 00100113  addi    sp, x0, 1
0x0070: 0220ef33  or      t5, ra, sp
0x0074: 00000e93  addi    t4, x0, 0
0x0078: 00600193  addi    gp, x0, 6
0x007c: 07df1463  bne     t5, t4, +104
0x0080: 00000093  addi    ra, x0, 0
0x0084: fff00113  addi    sp, x0, -1
0x0088: 0220ef33  or      t5, ra, sp
0x008c: 00000e93  addi    t4, x0, 0
0x0090: 00700193  addi    gp, x0, 7
0x0094: 05df1863  bne     t5, t4, +80
0x0098: 00000093  addi    ra, x0, 0
0x009c: 00000113  addi    sp, x0, 0
0x00a0: 0220ef33  or      t5, ra, sp
0x00a4: 00000e93  addi    t4, x0, 0
0x00a8: 00800193  addi    gp, x0, 8
0x00ac: 03df1c63  bne     t5, t4, +56
0x00b0: 00100093  addi    ra, x0, 1
0x00b4: 00000113  addi    sp, x0, 0
0x00b8: 0220ef33  or      t5, ra, sp
0x00bc: 00100e93  addi    t4, x0, 1
0x00c0: 00900193  addi    gp, x0, 9
0x00c4: 03df1063  bne     t5, t4, +32
0x00c8: 00000093  addi    ra, x0, 0
0x00cc: 00000113  addi    sp, x0, 0
0x00d0: 0220ef33  or      t5, ra, sp
0x00d4: 00000e93  addi    t4, x0, 0
0x00d8: 00a00193  addi    gp, x0, 10
0x00dc: 01df1463  bne     t5, t4, +8
0x00e0: 00301863  bne     x0, gp, +16
0x00e4: 00100d13  addi    s10, x0, 1
0x00e8: 00000d93  addi    s11, x0, 0
0x00ec: 0000006f  j       0              # halt loop
0x00f0: 00100d13  addi    s10, x0, 1
0x00f4: 00100d93  addi    s11, x0, 1
0x00f8: 0000006f  j       0              # halt loop
```

### inst_remu  \[PASS ✅\]

- **ROM 行数：** 98 行（含 NOP 填充），有效指令 63 条
- **指令分布：** ADDI×42, AND×9, BNE×10, JAL×2

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 01400093  addi    ra, x0, 20
0x000c: 00600113  addi    sp, x0, 6
0x0010: 0220ff33  and     t5, ra, sp
0x0014: 00200e93  addi    t4, x0, 2
0x0018: 00200193  addi    gp, x0, 2
0x001c: 0ddf1463  bne     t5, t4, +200
0x0020: fec00093  addi    ra, x0, -20
0x0024: 00600113  addi    sp, x0, 6
0x0028: 0220ff33  and     t5, ra, sp
0x002c: 00200e93  addi    t4, x0, 2
0x0030: 00300193  addi    gp, x0, 3
0x0034: 0bdf1863  bne     t5, t4, +176
0x0038: 01400093  addi    ra, x0, 20
0x003c: ffa00113  addi    sp, x0, -6
0x0040: 0220ff33  and     t5, ra, sp
0x0044: 01400e93  addi    t4, x0, 20
0x0048: 00400193  addi    gp, x0, 4
0x004c: 09df1c63  bne     t5, t4, +152
0x0050: fec00093  addi    ra, x0, -20
0x0054: ffa00113  addi    sp, x0, -6
0x0058: 0220ff33  and     t5, ra, sp
0x005c: fec00e93  addi    t4, x0, -20
0x0060: 00500193  addi    gp, x0, 5
0x0064: 09df1063  bne     t5, t4, +128
0x0068: 00000093  addi    ra, x0, 0
0x006c: 00100113  addi    sp, x0, 1
0x0070: 0220ff33  and     t5, ra, sp
0x0074: 00000e93  addi    t4, x0, 0
0x0078: 00600193  addi    gp, x0, 6
0x007c: 07df1463  bne     t5, t4, +104
0x0080: 00000093  addi    ra, x0, 0
0x0084: fff00113  addi    sp, x0, -1
0x0088: 0220ff33  and     t5, ra, sp
0x008c: 00000e93  addi    t4, x0, 0
0x0090: 00700193  addi    gp, x0, 7
0x0094: 05df1863  bne     t5, t4, +80
0x0098: 00000093  addi    ra, x0, 0
0x009c: 00000113  addi    sp, x0, 0
0x00a0: 0220ff33  and     t5, ra, sp
0x00a4: 00000e93  addi    t4, x0, 0
0x00a8: 00800193  addi    gp, x0, 8
0x00ac: 03df1c63  bne     t5, t4, +56
0x00b0: 00100093  addi    ra, x0, 1
0x00b4: 00000113  addi    sp, x0, 0
0x00b8: 0220ff33  and     t5, ra, sp
0x00bc: 00100e93  addi    t4, x0, 1
0x00c0: 00900193  addi    gp, x0, 9
0x00c4: 03df1063  bne     t5, t4, +32
0x00c8: 00000093  addi    ra, x0, 0
0x00cc: 00000113  addi    sp, x0, 0
0x00d0: 0220ff33  and     t5, ra, sp
0x00d4: 00000e93  addi    t4, x0, 0
0x00d8: 00a00193  addi    gp, x0, 10
0x00dc: 01df1463  bne     t5, t4, +8
0x00e0: 00301863  bne     x0, gp, +16
0x00e4: 00100d13  addi    s10, x0, 1
0x00e8: 00000d93  addi    s11, x0, 0
0x00ec: 0000006f  j       0              # halt loop
0x00f0: 00100d13  addi    s10, x0, 1
0x00f4: 00100d93  addi    s11, x0, 1
0x00f8: 0000006f  j       0              # halt loop
```

### inst_simple  \[PASS ✅\]

- **ROM 行数：** 50 行（含 NOP 填充），有效指令 5 条
- **指令分布：** ADDI×4, JAL×1

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00100d13  addi    s10, x0, 1
0x000c: 00100d93  addi    s11, x0, 1
0x0010: 0000006f  j       0              # halt loop
```

### inst_slli  \[FAIL ❌（超时）\]

- **ROM 行数：** 210 行（含 NOP 填充），有效指令 169 条
- **指令分布：** ADDI×94, BNE×31, JAL×2, LUI×18, SLLI×24

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00100093  addi    ra, x0, 1
0x000c: 00009f13  slli    t5, ra, 0
0x0010: 00100e93  addi    t4, x0, 1
0x0014: 00200193  addi    gp, x0, 2
0x0018: 27df1a63  bne     t5, t4, +628
0x001c: 00100093  addi    ra, x0, 1
0x0020: 00109f13  slli    t5, ra, 1
0x0024: 00200e93  addi    t4, x0, 2
0x0028: 00300193  addi    gp, x0, 3
0x002c: 27df1063  bne     t5, t4, +608
0x0030: 00100093  addi    ra, x0, 1
0x0034: 00709f13  slli    t5, ra, 7
0x0038: 08000e93  addi    t4, x0, 128
0x003c: 00400193  addi    gp, x0, 4
0x0040: 25df1663  bne     t5, t4, +588
0x0044: 00100093  addi    ra, x0, 1
0x0048: 00e09f13  slli    t5, ra, 14
0x004c: 00004eb7  lui     t4, 0x00004
0x0050: 00500193  addi    gp, x0, 5
0x0054: 23df1c63  bne     t5, t4, +568
0x0058: 00100093  addi    ra, x0, 1
0x005c: 01f09f13  slli    t5, ra, 31
0x0060: 80000eb7  lui     t4, 0x80000
0x0064: 00600193  addi    gp, x0, 6
0x0068: 23df1263  bne     t5, t4, +548
0x006c: fff00093  addi    ra, x0, -1
0x0070: 00009f13  slli    t5, ra, 0
0x0074: fff00e93  addi    t4, x0, -1
0x0078: 00700193  addi    gp, x0, 7
0x007c: 21df1863  bne     t5, t4, +528
0x0080: fff00093  addi    ra, x0, -1
0x0084: 00109f13  slli    t5, ra, 1
0x0088: ffe00e93  addi    t4, x0, -2
0x008c: 00800193  addi    gp, x0, 8
0x0090: 1fdf1e63  bne     t5, t4, +508
0x0094: fff00093  addi    ra, x0, -1
0x0098: 00709f13  slli    t5, ra, 7
0x009c: f8000e93  addi    t4, x0, -128
0x00a0: 00900193  addi    gp, x0, 9
0x00a4: 1fdf1463  bne     t5, t4, +488
0x00a8: fff00093  addi    ra, x0, -1
0x00ac: 00e09f13  slli    t5, ra, 14
0x00b0: ffffceb7  lui     t4, 0xffffc
0x00b4: 00a00193  addi    gp, x0, 10
0x00b8: 1ddf1a63  bne     t5, t4, +468
0x00bc: fff00093  addi    ra, x0, -1
0x00c0: 01f09f13  slli    t5, ra, 31
0x00c4: 80000eb7  lui     t4, 0x80000
0x00c8: 00b00193  addi    gp, x0, 11
0x00cc: 1ddf1063  bne     t5, t4, +448
0x00d0: 212120b7  lui     ra, 0x21212
0x00d4: 12108093  addi    ra, ra, 289
0x00d8: 00009f13  slli    t5, ra, 0
0x00dc: 21212eb7  lui     t4, 0x21212
0x00e0: 121e8e93  addi    t4, t4, 289
0x00e4: 00c00193  addi    gp, x0, 12
0x00e8: 1bdf1263  bne     t5, t4, +420
0x00ec: 212120b7  lui     ra, 0x21212
0x00f0: 12108093  addi    ra, ra, 289
0x00f4: 00109f13  slli    t5, ra, 1
0x00f8: 42424eb7  lui     t4, 0x42424
0x00fc: 242e8e93  addi    t4, t4, 578
0x0100: 00d00193  addi    gp, x0, 13
0x0104: 19df1463  bne     t5, t4, +392
0x0108: 212120b7  lui     ra, 0x21212
0x010c: 12108093  addi    ra, ra, 289
0x0110: 00709f13  slli    t5, ra, 7
0x0114: 90909eb7  lui     t4, 0x90909
0x0118: 080e8e93  addi    t4, t4, 128
0x011c: 00e00193  addi    gp, x0, 14
0x0120: 17df1663  bne     t5, t4, +364
0x0124: 212120b7  lui     ra, 0x21212
0x0128: 12108093  addi    ra, ra, 289
0x012c: 00e09f13  slli    t5, ra, 14
0x0130: 48484eb7  lui     t4, 0x48484
0x0134: 00f00193  addi    gp, x0, 15
0x0138: 15df1a63  bne     t5, t4, +340
0x013c: 212120b7  lui     ra, 0x21212
0x0140: 12108093  addi    ra, ra, 289
0x0144: 01f09f13  slli    t5, ra, 31
0x0148: 80000eb7  lui     t4, 0x80000
0x014c: 01000193  addi    gp, x0, 16
0x0150: 13df1e63  bne     t5, t4, +316
0x0154: 00100093  addi    ra, x0, 1
0x0158: 00709093  slli    ra, ra, 7
0x015c: 08000e93  addi    t4, x0, 128
0x0160: 01100193  addi    gp, x0, 17
0x0164: 13d09463  bne     ra, t4, +296
0x0168: 00000213  addi    tp, x0, 0
0x016c: 00100093  addi    ra, x0, 1
0x0170: 00709f13  slli    t5, ra, 7
0x0174: 000f0313  addi    t1, t5, 0
0x0178: 00120213  addi    tp, tp, 1
0x017c: 00200293  addi    t0, x0, 2
0x0180: fe5216e3  bne     tp, t0, -20
0x0184: 08000e93  addi    t4, x0, 128
0x0188: 01200193  addi    gp, x0, 18
0x018c: 11d31063  bne     t1, t4, +256
0x0190: 00000213  addi    tp, x0, 0
0x0194: 00100093  addi    ra, x0, 1
0x0198: 00e09f13  slli    t5, ra, 14
0x019c: 00000013  addi    x0, x0, 0
0x01a0: 000f0313  addi    t1, t5, 0
0x01a4: 00120213  addi    tp, tp, 1
0x01a8: 00200293  addi    t0, x0, 2
0x01ac: fe5214e3  bne     tp, t0, -24
0x01b0: 00004eb7  lui     t4, 0x00004
0x01b4: 01300193  addi    gp, x0, 19
0x01b8: 0dd31a63  bne     t1, t4, +212
0x01bc: 00000213  addi    tp, x0, 0
0x01c0: 00100093  addi    ra, x0, 1
0x01c4: 01f09f13  slli    t5, ra, 31
0x01c8: 00000013  addi    x0, x0, 0
0x01cc: 00000013  addi    x0, x0, 0
0x01d0: 000f0313  addi    t1, t5, 0
0x01d4: 00120213  addi    tp, tp, 1
0x01d8: 00200293  addi    t0, x0, 2
0x01dc: fe5212e3  bne     tp, t0, -28
0x01e0: 80000eb7  lui     t4, 0x80000
0x01e4: 01400193  addi    gp, x0, 20
0x01e8: 0bd31263  bne     t1, t4, +164
0x01ec: 00000213  addi    tp, x0, 0
0x01f0: 00100093  addi    ra, x0, 1
0x01f4: 00709f13  slli    t5, ra, 7
0x01f8: 00120213  addi    tp, tp, 1
0x01fc: 00200293  addi    t0, x0, 2
0x0200: fe5218e3  bne     tp, t0, -16
0x0204: 08000e93  addi    t4, x0, 128
0x0208: 01500193  addi    gp, x0, 21
0x020c: 09df1063  bne     t5, t4, +128
0x0210: 00000213  addi    tp, x0, 0
0x0214: 00100093  addi    ra, x0, 1
0x0218: 00000013  addi    x0, x0, 0
0x021c: 00e09f13  slli    t5, ra, 14
0x0220: 00120213  addi    tp, tp, 1
0x0224: 00200293  addi    t0, x0, 2
0x0228: fe5216e3  bne     tp, t0, -20
0x022c: 00004eb7  lui     t4, 0x00004
0x0230: 01600193  addi    gp, x0, 22
0x0234: 05df1c63  bne     t5, t4, +88
0x0238: 00000213  addi    tp, x0, 0
0x023c: 00100093  addi    ra, x0, 1
0x0240: 00000013  addi    x0, x0, 0
0x0244: 00000013  addi    x0, x0, 0
0x0248: 01f09f13  slli    t5, ra, 31
0x024c: 00120213  addi    tp, tp, 1
0x0250: 00200293  addi    t0, x0, 2
0x0254: fe5214e3  bne     tp, t0, -24
0x0258: 80000eb7  lui     t4, 0x80000
0x025c: 01700193  addi    gp, x0, 23
0x0260: 03df1663  bne     t5, t4, +44
0x0264: 01f01093  slli    ra, x0, 31
0x0268: 00000e93  addi    t4, x0, 0
0x026c: 01800193  addi    gp, x0, 24
0x0270: 01d09e63  bne     ra, t4, +28
0x0274: 02100093  addi    ra, x0, 33
0x0278: 01409013  slli    x0, ra, 20
0x027c: 00000e93  addi    t4, x0, 0
0x0280: 01900193  addi    gp, x0, 25
0x0284: 01d01463  bne     x0, t4, +8
0x0288: 00301863  bne     x0, gp, +16
0x028c: 00100d13  addi    s10, x0, 1
0x0290: 00000d93  addi    s11, x0, 0
0x0294: 0000006f  j       0              # halt loop
0x0298: 00100d13  addi    s10, x0, 1
0x029c: 00100d93  addi    s11, x0, 1
0x02a0: 0000006f  j       0              # halt loop
```

### inst_slti  \[FAIL ❌（超时）\]

- **ROM 行数：** 210 行（含 NOP 填充），有效指令 165 条
- **指令分布：** ADDI×101, BNE×31, JAL×2, LUI×7, SLTI×24

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00000093  addi    ra, x0, 0
0x000c: 0000af13  slti    t5, ra, 0
0x0010: 00000e93  addi    t4, x0, 0
0x0014: 00200193  addi    gp, x0, 2
0x0018: 27df1263  bne     t5, t4, +612
0x001c: 00100093  addi    ra, x0, 1
0x0020: 0010af13  slti    t5, ra, 1
0x0024: 00000e93  addi    t4, x0, 0
0x0028: 00300193  addi    gp, x0, 3
0x002c: 25df1863  bne     t5, t4, +592
0x0030: 00300093  addi    ra, x0, 3
0x0034: 0070af13  slti    t5, ra, 7
0x0038: 00100e93  addi    t4, x0, 1
0x003c: 00400193  addi    gp, x0, 4
0x0040: 23df1e63  bne     t5, t4, +572
0x0044: 00700093  addi    ra, x0, 7
0x0048: 0030af13  slti    t5, ra, 3
0x004c: 00000e93  addi    t4, x0, 0
0x0050: 00500193  addi    gp, x0, 5
0x0054: 23df1463  bne     t5, t4, +552
0x0058: 00000093  addi    ra, x0, 0
0x005c: 8000af13  slti    t5, ra, -2048
0x0060: 00000e93  addi    t4, x0, 0
0x0064: 00600193  addi    gp, x0, 6
0x0068: 21df1a63  bne     t5, t4, +532
0x006c: 800000b7  lui     ra, 0x80000
0x0070: 0000af13  slti    t5, ra, 0
0x0074: 00100e93  addi    t4, x0, 1
0x0078: 00700193  addi    gp, x0, 7
0x007c: 21df1063  bne     t5, t4, +512
0x0080: 800000b7  lui     ra, 0x80000
0x0084: 8000af13  slti    t5, ra, -2048
0x0088: 00100e93  addi    t4, x0, 1
0x008c: 00800193  addi    gp, x0, 8
0x0090: 1fdf1663  bne     t5, t4, +492
0x0094: 00000093  addi    ra, x0, 0
0x0098: 7ff0af13  slti    t5, ra, 2047
0x009c: 00100e93  addi    t4, x0, 1
0x00a0: 00900193  addi    gp, x0, 9
0x00a4: 1ddf1c63  bne     t5, t4, +472
0x00a8: 800000b7  lui     ra, 0x80000
0x00ac: fff08093  addi    ra, ra, -1
0x00b0: 0000af13  slti    t5, ra, 0
0x00b4: 00000e93  addi    t4, x0, 0
0x00b8: 00a00193  addi    gp, x0, 10
0x00bc: 1ddf1063  bne     t5, t4, +448
0x00c0: 800000b7  lui     ra, 0x80000
0x00c4: fff08093  addi    ra, ra, -1
0x00c8: 7ff0af13  slti    t5, ra, 2047
0x00cc: 00000e93  addi    t4, x0, 0
0x00d0: 00b00193  addi    gp, x0, 11
0x00d4: 1bdf1463  bne     t5, t4, +424
0x00d8: 800000b7  lui     ra, 0x80000
0x00dc: 7ff0af13  slti    t5, ra, 2047
0x00e0: 00100e93  addi    t4, x0, 1
0x00e4: 00c00193  addi    gp, x0, 12
0x00e8: 19df1a63  bne     t5, t4, +404
0x00ec: 800000b7  lui     ra, 0x80000
0x00f0: fff08093  addi    ra, ra, -1
0x00f4: 8000af13  slti    t5, ra, -2048
0x00f8: 00000e93  addi    t4, x0, 0
0x00fc: 00d00193  addi    gp, x0, 13
0x0100: 17df1e63  bne     t5, t4, +380
0x0104: 00000093  addi    ra, x0, 0
0x0108: fff0af13  slti    t5, ra, -1
0x010c: 00000e93  addi    t4, x0, 0
0x0110: 00e00193  addi    gp, x0, 14
0x0114: 17df1463  bne     t5, t4, +360
0x0118: fff00093  addi    ra, x0, -1
0x011c: 0010af13  slti    t5, ra, 1
0x0120: 00100e93  addi    t4, x0, 1
0x0124: 00f00193  addi    gp, x0, 15
0x0128: 15df1a63  bne     t5, t4, +340
0x012c: fff00093  addi    ra, x0, -1
0x0130: fff0af13  slti    t5, ra, -1
0x0134: 00000e93  addi    t4, x0, 0
0x0138: 01000193  addi    gp, x0, 16
0x013c: 15df1063  bne     t5, t4, +320
0x0140: 00b00093  addi    ra, x0, 11
0x0144: 00d0a093  slti    ra, ra, 13
0x0148: 00100e93  addi    t4, x0, 1
0x014c: 01100193  addi    gp, x0, 17
0x0150: 13d09663  bne     ra, t4, +300
0x0154: 00000213  addi    tp, x0, 0
0x0158: 00f00093  addi    ra, x0, 15
0x015c: 00a0af13  slti    t5, ra, 10
0x0160: 000f0313  addi    t1, t5, 0
0x0164: 00120213  addi    tp, tp, 1
0x0168: 00200293  addi    t0, x0, 2
0x016c: fe5216e3  bne     tp, t0, -20
0x0170: 00000e93  addi    t4, x0, 0
0x0174: 01200193  addi    gp, x0, 18
0x0178: 11d31263  bne     t1, t4, +260
0x017c: 00000213  addi    tp, x0, 0
0x0180: 00a00093  addi    ra, x0, 10
0x0184: 0100af13  slti    t5, ra, 16
0x0188: 00000013  addi    x0, x0, 0
0x018c: 000f0313  addi    t1, t5, 0
0x0190: 00120213  addi    tp, tp, 1
0x0194: 00200293  addi    t0, x0, 2
0x0198: fe5214e3  bne     tp, t0, -24
0x019c: 00100e93  addi    t4, x0, 1
0x01a0: 01300193  addi    gp, x0, 19
0x01a4: 0dd31c63  bne     t1, t4, +216
0x01a8: 00000213  addi    tp, x0, 0
0x01ac: 01000093  addi    ra, x0, 16
0x01b0: 0090af13  slti    t5, ra, 9
0x01b4: 00000013  addi    x0, x0, 0
0x01b8: 00000013  addi    x0, x0, 0
0x01bc: 000f0313  addi    t1, t5, 0
0x01c0: 00120213  addi    tp, tp, 1
0x01c4: 00200293  addi    t0, x0, 2
0x01c8: fe5212e3  bne     tp, t0, -28
0x01cc: 00000e93  addi    t4, x0, 0
0x01d0: 01400193  addi    gp, x0, 20
0x01d4: 0bd31463  bne     t1, t4, +168
0x01d8: 00000213  addi    tp, x0, 0
0x01dc: 00b00093  addi    ra, x0, 11
0x01e0: 00f0af13  slti    t5, ra, 15
0x01e4: 00120213  addi    tp, tp, 1
0x01e8: 00200293  addi    t0, x0, 2
0x01ec: fe5218e3  bne     tp, t0, -16
0x01f0: 00100e93  addi    t4, x0, 1
0x01f4: 01500193  addi    gp, x0, 21
0x01f8: 09df1263  bne     t5, t4, +132
0x01fc: 00000213  addi    tp, x0, 0
0x0200: 01100093  addi    ra, x0, 17
0x0204: 00000013  addi    x0, x0, 0
0x0208: 0080af13  slti    t5, ra, 8
0x020c: 00120213  addi    tp, tp, 1
0x0210: 00200293  addi    t0, x0, 2
0x0214: fe5216e3  bne     tp, t0, -20
0x0218: 00000e93  addi    t4, x0, 0
0x021c: 01600193  addi    gp, x0, 22
0x0220: 05df1e63  bne     t5, t4, +92
0x0224: 00000213  addi    tp, x0, 0
0x0228: 00c00093  addi    ra, x0, 12
0x022c: 00000013  addi    x0, x0, 0
0x0230: 00000013  addi    x0, x0, 0
0x0234: 00e0af13  slti    t5, ra, 14
0x0238: 00120213  addi    tp, tp, 1
0x023c: 00200293  addi    t0, x0, 2
0x0240: fe5214e3  bne     tp, t0, -24
0x0244: 00100e93  addi    t4, x0, 1
0x0248: 01700193  addi    gp, x0, 23
0x024c: 03df1863  bne     t5, t4, +48
0x0250: fff02093  slti    ra, x0, -1
0x0254: 00000e93  addi    t4, x0, 0
0x0258: 01800193  addi    gp, x0, 24
0x025c: 03d09063  bne     ra, t4, +32
0x0260: 00ff00b7  lui     ra, 0x00ff0
0x0264: 0ff08093  addi    ra, ra, 255
0x0268: fff0a013  slti    x0, ra, -1
0x026c: 00000e93  addi    t4, x0, 0
0x0270: 01900193  addi    gp, x0, 25
0x0274: 01d01463  bne     x0, t4, +8
0x0278: 00301863  bne     x0, gp, +16
0x027c: 00100d13  addi    s10, x0, 1
0x0280: 00000d93  addi    s11, x0, 0
0x0284: 0000006f  j       0              # halt loop
0x0288: 00100d13  addi    s10, x0, 1
0x028c: 00100d93  addi    s11, x0, 1
0x0290: 0000006f  j       0              # halt loop
```

### inst_sltiu  \[FAIL ❌（超时）\]

- **ROM 行数：** 210 行（含 NOP 填充），有效指令 165 条
- **指令分布：** ADDI×101, BNE×31, JAL×2, LUI×7, SLTIU×24

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00000093  addi    ra, x0, 0
0x000c: 0000bf13  sltiu   t5, ra, 0
0x0010: 00000e93  addi    t4, x0, 0
0x0014: 00200193  addi    gp, x0, 2
0x0018: 27df1263  bne     t5, t4, +612
0x001c: 00100093  addi    ra, x0, 1
0x0020: 0010bf13  sltiu   t5, ra, 1
0x0024: 00000e93  addi    t4, x0, 0
0x0028: 00300193  addi    gp, x0, 3
0x002c: 25df1863  bne     t5, t4, +592
0x0030: 00300093  addi    ra, x0, 3
0x0034: 0070bf13  sltiu   t5, ra, 7
0x0038: 00100e93  addi    t4, x0, 1
0x003c: 00400193  addi    gp, x0, 4
0x0040: 23df1e63  bne     t5, t4, +572
0x0044: 00700093  addi    ra, x0, 7
0x0048: 0030bf13  sltiu   t5, ra, 3
0x004c: 00000e93  addi    t4, x0, 0
0x0050: 00500193  addi    gp, x0, 5
0x0054: 23df1463  bne     t5, t4, +552
0x0058: 00000093  addi    ra, x0, 0
0x005c: 8000bf13  sltiu   t5, ra, -2048
0x0060: 00100e93  addi    t4, x0, 1
0x0064: 00600193  addi    gp, x0, 6
0x0068: 21df1a63  bne     t5, t4, +532
0x006c: 800000b7  lui     ra, 0x80000
0x0070: 0000bf13  sltiu   t5, ra, 0
0x0074: 00000e93  addi    t4, x0, 0
0x0078: 00700193  addi    gp, x0, 7
0x007c: 21df1063  bne     t5, t4, +512
0x0080: 800000b7  lui     ra, 0x80000
0x0084: 8000bf13  sltiu   t5, ra, -2048
0x0088: 00100e93  addi    t4, x0, 1
0x008c: 00800193  addi    gp, x0, 8
0x0090: 1fdf1663  bne     t5, t4, +492
0x0094: 00000093  addi    ra, x0, 0
0x0098: 7ff0bf13  sltiu   t5, ra, 2047
0x009c: 00100e93  addi    t4, x0, 1
0x00a0: 00900193  addi    gp, x0, 9
0x00a4: 1ddf1c63  bne     t5, t4, +472
0x00a8: 800000b7  lui     ra, 0x80000
0x00ac: fff08093  addi    ra, ra, -1
0x00b0: 0000bf13  sltiu   t5, ra, 0
0x00b4: 00000e93  addi    t4, x0, 0
0x00b8: 00a00193  addi    gp, x0, 10
0x00bc: 1ddf1063  bne     t5, t4, +448
0x00c0: 800000b7  lui     ra, 0x80000
0x00c4: fff08093  addi    ra, ra, -1
0x00c8: 7ff0bf13  sltiu   t5, ra, 2047
0x00cc: 00000e93  addi    t4, x0, 0
0x00d0: 00b00193  addi    gp, x0, 11
0x00d4: 1bdf1463  bne     t5, t4, +424
0x00d8: 800000b7  lui     ra, 0x80000
0x00dc: 7ff0bf13  sltiu   t5, ra, 2047
0x00e0: 00000e93  addi    t4, x0, 0
0x00e4: 00c00193  addi    gp, x0, 12
0x00e8: 19df1a63  bne     t5, t4, +404
0x00ec: 800000b7  lui     ra, 0x80000
0x00f0: fff08093  addi    ra, ra, -1
0x00f4: 8000bf13  sltiu   t5, ra, -2048
0x00f8: 00100e93  addi    t4, x0, 1
0x00fc: 00d00193  addi    gp, x0, 13
0x0100: 17df1e63  bne     t5, t4, +380
0x0104: 00000093  addi    ra, x0, 0
0x0108: fff0bf13  sltiu   t5, ra, -1
0x010c: 00100e93  addi    t4, x0, 1
0x0110: 00e00193  addi    gp, x0, 14
0x0114: 17df1463  bne     t5, t4, +360
0x0118: fff00093  addi    ra, x0, -1
0x011c: 0010bf13  sltiu   t5, ra, 1
0x0120: 00000e93  addi    t4, x0, 0
0x0124: 00f00193  addi    gp, x0, 15
0x0128: 15df1a63  bne     t5, t4, +340
0x012c: fff00093  addi    ra, x0, -1
0x0130: fff0bf13  sltiu   t5, ra, -1
0x0134: 00000e93  addi    t4, x0, 0
0x0138: 01000193  addi    gp, x0, 16
0x013c: 15df1063  bne     t5, t4, +320
0x0140: 00b00093  addi    ra, x0, 11
0x0144: 00d0b093  sltiu   ra, ra, 13
0x0148: 00100e93  addi    t4, x0, 1
0x014c: 01100193  addi    gp, x0, 17
0x0150: 13d09663  bne     ra, t4, +300
0x0154: 00000213  addi    tp, x0, 0
0x0158: 00f00093  addi    ra, x0, 15
0x015c: 00a0bf13  sltiu   t5, ra, 10
0x0160: 000f0313  addi    t1, t5, 0
0x0164: 00120213  addi    tp, tp, 1
0x0168: 00200293  addi    t0, x0, 2
0x016c: fe5216e3  bne     tp, t0, -20
0x0170: 00000e93  addi    t4, x0, 0
0x0174: 01200193  addi    gp, x0, 18
0x0178: 11d31263  bne     t1, t4, +260
0x017c: 00000213  addi    tp, x0, 0
0x0180: 00a00093  addi    ra, x0, 10
0x0184: 0100bf13  sltiu   t5, ra, 16
0x0188: 00000013  addi    x0, x0, 0
0x018c: 000f0313  addi    t1, t5, 0
0x0190: 00120213  addi    tp, tp, 1
0x0194: 00200293  addi    t0, x0, 2
0x0198: fe5214e3  bne     tp, t0, -24
0x019c: 00100e93  addi    t4, x0, 1
0x01a0: 01300193  addi    gp, x0, 19
0x01a4: 0dd31c63  bne     t1, t4, +216
0x01a8: 00000213  addi    tp, x0, 0
0x01ac: 01000093  addi    ra, x0, 16
0x01b0: 0090bf13  sltiu   t5, ra, 9
0x01b4: 00000013  addi    x0, x0, 0
0x01b8: 00000013  addi    x0, x0, 0
0x01bc: 000f0313  addi    t1, t5, 0
0x01c0: 00120213  addi    tp, tp, 1
0x01c4: 00200293  addi    t0, x0, 2
0x01c8: fe5212e3  bne     tp, t0, -28
0x01cc: 00000e93  addi    t4, x0, 0
0x01d0: 01400193  addi    gp, x0, 20
0x01d4: 0bd31463  bne     t1, t4, +168
0x01d8: 00000213  addi    tp, x0, 0
0x01dc: 00b00093  addi    ra, x0, 11
0x01e0: 00f0bf13  sltiu   t5, ra, 15
0x01e4: 00120213  addi    tp, tp, 1
0x01e8: 00200293  addi    t0, x0, 2
0x01ec: fe5218e3  bne     tp, t0, -16
0x01f0: 00100e93  addi    t4, x0, 1
0x01f4: 01500193  addi    gp, x0, 21
0x01f8: 09df1263  bne     t5, t4, +132
0x01fc: 00000213  addi    tp, x0, 0
0x0200: 01100093  addi    ra, x0, 17
0x0204: 00000013  addi    x0, x0, 0
0x0208: 0080bf13  sltiu   t5, ra, 8
0x020c: 00120213  addi    tp, tp, 1
0x0210: 00200293  addi    t0, x0, 2
0x0214: fe5216e3  bne     tp, t0, -20
0x0218: 00000e93  addi    t4, x0, 0
0x021c: 01600193  addi    gp, x0, 22
0x0220: 05df1e63  bne     t5, t4, +92
0x0224: 00000213  addi    tp, x0, 0
0x0228: 00c00093  addi    ra, x0, 12
0x022c: 00000013  addi    x0, x0, 0
0x0230: 00000013  addi    x0, x0, 0
0x0234: 00e0bf13  sltiu   t5, ra, 14
0x0238: 00120213  addi    tp, tp, 1
0x023c: 00200293  addi    t0, x0, 2
0x0240: fe5214e3  bne     tp, t0, -24
0x0244: 00100e93  addi    t4, x0, 1
0x0248: 01700193  addi    gp, x0, 23
0x024c: 03df1863  bne     t5, t4, +48
0x0250: fff03093  sltiu   ra, x0, -1
0x0254: 00100e93  addi    t4, x0, 1
0x0258: 01800193  addi    gp, x0, 24
0x025c: 03d09063  bne     ra, t4, +32
0x0260: 00ff00b7  lui     ra, 0x00ff0
0x0264: 0ff08093  addi    ra, ra, 255
0x0268: fff0b013  sltiu   x0, ra, -1
0x026c: 00000e93  addi    t4, x0, 0
0x0270: 01900193  addi    gp, x0, 25
0x0274: 01d01463  bne     x0, t4, +8
0x0278: 00301863  bne     x0, gp, +16
0x027c: 00100d13  addi    s10, x0, 1
0x0280: 00000d93  addi    s11, x0, 0
0x0284: 0000006f  j       0              # halt loop
0x0288: 00100d13  addi    s10, x0, 1
0x028c: 00100d93  addi    s11, x0, 1
0x0290: 0000006f  j       0              # halt loop
```

### inst_srai  \[FAIL ❌（超时）\]

- **ROM 行数：** 226 行（含 NOP 填充），有效指令 182 条
- **指令分布：** ADDI×88, BNE×31, JAL×2, LUI×37, SRAI×24

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00000093  addi    ra, x0, 0
0x000c: 4000df13  srai    t5, ra, 0
0x0010: 00000e93  addi    t4, x0, 0
0x0014: 00200193  addi    gp, x0, 2
0x0018: 2bdf1463  bne     t5, t4, +680
0x001c: 800000b7  lui     ra, 0x80000
0x0020: 4010df13  srai    t5, ra, 1
0x0024: c0000eb7  lui     t4, 0xc0000
0x0028: 00300193  addi    gp, x0, 3
0x002c: 29df1a63  bne     t5, t4, +660
0x0030: 800000b7  lui     ra, 0x80000
0x0034: 4070df13  srai    t5, ra, 7
0x0038: ff000eb7  lui     t4, 0xff000
0x003c: 00400193  addi    gp, x0, 4
0x0040: 29df1063  bne     t5, t4, +640
0x0044: 800000b7  lui     ra, 0x80000
0x0048: 40e0df13  srai    t5, ra, 14
0x004c: fffe0eb7  lui     t4, 0xfffe0
0x0050: 00500193  addi    gp, x0, 5
0x0054: 27df1663  bne     t5, t4, +620
0x0058: 800000b7  lui     ra, 0x80000
0x005c: 00108093  addi    ra, ra, 1
0x0060: 41f0df13  srai    t5, ra, 31
0x0064: fff00e93  addi    t4, x0, -1
0x0068: 00600193  addi    gp, x0, 6
0x006c: 25df1a63  bne     t5, t4, +596
0x0070: 800000b7  lui     ra, 0x80000
0x0074: fff08093  addi    ra, ra, -1
0x0078: 4000df13  srai    t5, ra, 0
0x007c: 80000eb7  lui     t4, 0x80000
0x0080: fffe8e93  addi    t4, t4, -1
0x0084: 00700193  addi    gp, x0, 7
0x0088: 23df1c63  bne     t5, t4, +568
0x008c: 800000b7  lui     ra, 0x80000
0x0090: fff08093  addi    ra, ra, -1
0x0094: 4010df13  srai    t5, ra, 1
0x0098: 40000eb7  lui     t4, 0x40000
0x009c: fffe8e93  addi    t4, t4, -1
0x00a0: 00800193  addi    gp, x0, 8
0x00a4: 21df1e63  bne     t5, t4, +540
0x00a8: 800000b7  lui     ra, 0x80000
0x00ac: fff08093  addi    ra, ra, -1
0x00b0: 4070df13  srai    t5, ra, 7
0x00b4: 01000eb7  lui     t4, 0x01000
0x00b8: fffe8e93  addi    t4, t4, -1
0x00bc: 00900193  addi    gp, x0, 9
0x00c0: 21df1063  bne     t5, t4, +512
0x00c4: 800000b7  lui     ra, 0x80000
0x00c8: fff08093  addi    ra, ra, -1
0x00cc: 40e0df13  srai    t5, ra, 14
0x00d0: 00020eb7  lui     t4, 0x00020
0x00d4: fffe8e93  addi    t4, t4, -1
0x00d8: 00a00193  addi    gp, x0, 10
0x00dc: 1fdf1263  bne     t5, t4, +484
0x00e0: 800000b7  lui     ra, 0x80000
0x00e4: fff08093  addi    ra, ra, -1
0x00e8: 41f0df13  srai    t5, ra, 31
0x00ec: 00000e93  addi    t4, x0, 0
0x00f0: 00b00193  addi    gp, x0, 11
0x00f4: 1ddf1663  bne     t5, t4, +460
0x00f8: 818180b7  lui     ra, 0x81818
0x00fc: 18108093  addi    ra, ra, 385
0x0100: 4000df13  srai    t5, ra, 0
0x0104: 81818eb7  lui     t4, 0x81818
0x0108: 181e8e93  addi    t4, t4, 385
0x010c: 00c00193  addi    gp, x0, 12
0x0110: 1bdf1863  bne     t5, t4, +432
0x0114: 818180b7  lui     ra, 0x81818
0x0118: 18108093  addi    ra, ra, 385
0x011c: 4010df13  srai    t5, ra, 1
0x0120: c0c0ceb7  lui     t4, 0xc0c0c
0x0124: 0c0e8e93  addi    t4, t4, 192
0x0128: 00d00193  addi    gp, x0, 13
0x012c: 19df1a63  bne     t5, t4, +404
0x0130: 818180b7  lui     ra, 0x81818
0x0134: 18108093  addi    ra, ra, 385
0x0138: 4070df13  srai    t5, ra, 7
0x013c: ff030eb7  lui     t4, 0xff030
0x0140: 303e8e93  addi    t4, t4, 771
0x0144: 00e00193  addi    gp, x0, 14
0x0148: 17df1c63  bne     t5, t4, +376
0x014c: 818180b7  lui     ra, 0x81818
0x0150: 18108093  addi    ra, ra, 385
0x0154: 40e0df13  srai    t5, ra, 14
0x0158: fffe0eb7  lui     t4, 0xfffe0
0x015c: 606e8e93  addi    t4, t4, 1542
0x0160: 00f00193  addi    gp, x0, 15
0x0164: 15df1e63  bne     t5, t4, +348
0x0168: 818180b7  lui     ra, 0x81818
0x016c: 18108093  addi    ra, ra, 385
0x0170: 41f0df13  srai    t5, ra, 31
0x0174: fff00e93  addi    t4, x0, -1
0x0178: 01000193  addi    gp, x0, 16
0x017c: 15df1263  bne     t5, t4, +324
0x0180: 800000b7  lui     ra, 0x80000
0x0184: 4070d093  srai    ra, ra, 7
0x0188: ff000eb7  lui     t4, 0xff000
0x018c: 01100193  addi    gp, x0, 17
0x0190: 13d09863  bne     ra, t4, +304
0x0194: 00000213  addi    tp, x0, 0
0x0198: 800000b7  lui     ra, 0x80000
0x019c: 4070df13  srai    t5, ra, 7
0x01a0: 000f0313  addi    t1, t5, 0
0x01a4: 00120213  addi    tp, tp, 1
0x01a8: 00200293  addi    t0, x0, 2
0x01ac: fe5216e3  bne     tp, t0, -20
0x01b0: ff000eb7  lui     t4, 0xff000
0x01b4: 01200193  addi    gp, x0, 18
0x01b8: 11d31463  bne     t1, t4, +264
0x01bc: 00000213  addi    tp, x0, 0
0x01c0: 800000b7  lui     ra, 0x80000
0x01c4: 40e0df13  srai    t5, ra, 14
0x01c8: 00000013  addi    x0, x0, 0
0x01cc: 000f0313  addi    t1, t5, 0
0x01d0: 00120213  addi    tp, tp, 1
0x01d4: 00200293  addi    t0, x0, 2
0x01d8: fe5214e3  bne     tp, t0, -24
0x01dc: fffe0eb7  lui     t4, 0xfffe0
0x01e0: 01300193  addi    gp, x0, 19
0x01e4: 0dd31e63  bne     t1, t4, +220
0x01e8: 00000213  addi    tp, x0, 0
0x01ec: 800000b7  lui     ra, 0x80000
0x01f0: 00108093  addi    ra, ra, 1
0x01f4: 41f0df13  srai    t5, ra, 31
0x01f8: 00000013  addi    x0, x0, 0
0x01fc: 00000013  addi    x0, x0, 0
0x0200: 000f0313  addi    t1, t5, 0
0x0204: 00120213  addi    tp, tp, 1
0x0208: 00200293  addi    t0, x0, 2
0x020c: fe5210e3  bne     tp, t0, -32
0x0210: fff00e93  addi    t4, x0, -1
0x0214: 01400193  addi    gp, x0, 20
0x0218: 0bd31463  bne     t1, t4, +168
0x021c: 00000213  addi    tp, x0, 0
0x0220: 800000b7  lui     ra, 0x80000
0x0224: 4070df13  srai    t5, ra, 7
0x0228: 00120213  addi    tp, tp, 1
0x022c: 00200293  addi    t0, x0, 2
0x0230: fe5218e3  bne     tp, t0, -16
0x0234: ff000eb7  lui     t4, 0xff000
0x0238: 01500193  addi    gp, x0, 21
0x023c: 09df1263  bne     t5, t4, +132
0x0240: 00000213  addi    tp, x0, 0
0x0244: 800000b7  lui     ra, 0x80000
0x0248: 00000013  addi    x0, x0, 0
0x024c: 40e0df13  srai    t5, ra, 14
0x0250: 00120213  addi    tp, tp, 1
0x0254: 00200293  addi    t0, x0, 2
0x0258: fe5216e3  bne     tp, t0, -20
0x025c: fffe0eb7  lui     t4, 0xfffe0
0x0260: 01600193  addi    gp, x0, 22
0x0264: 05df1e63  bne     t5, t4, +92
0x0268: 00000213  addi    tp, x0, 0
0x026c: 800000b7  lui     ra, 0x80000
0x0270: 00108093  addi    ra, ra, 1
0x0274: 00000013  addi    x0, x0, 0
0x0278: 00000013  addi    x0, x0, 0
0x027c: 41f0df13  srai    t5, ra, 31
0x0280: 00120213  addi    tp, tp, 1
0x0284: 00200293  addi    t0, x0, 2
0x0288: fe5212e3  bne     tp, t0, -28
0x028c: fff00e93  addi    t4, x0, -1
0x0290: 01700193  addi    gp, x0, 23
0x0294: 03df1663  bne     t5, t4, +44
0x0298: 40405093  srai    ra, x0, 4
0x029c: 00000e93  addi    t4, x0, 0
0x02a0: 01800193  addi    gp, x0, 24
0x02a4: 01d09e63  bne     ra, t4, +28
0x02a8: 02100093  addi    ra, x0, 33
0x02ac: 40a0d013  srai    x0, ra, 10
0x02b0: 00000e93  addi    t4, x0, 0
0x02b4: 01900193  addi    gp, x0, 25
0x02b8: 01d01463  bne     x0, t4, +8
0x02bc: 00301863  bne     x0, gp, +16
0x02c0: 00100d13  addi    s10, x0, 1
0x02c4: 00000d93  addi    s11, x0, 0
0x02c8: 0000006f  j       0              # halt loop
0x02cc: 00100d13  addi    s10, x0, 1
0x02d0: 00100d93  addi    s11, x0, 1
0x02d4: 0000006f  j       0              # halt loop
```

### inst_srli  \[FAIL ❌（超时）\]

- **ROM 行数：** 210 行（含 NOP 填充），有效指令 176 条
- **指令分布：** ADDI×86, BNE×31, JAL×2, LUI×33, SRLI×24

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 800000b7  lui     ra, 0x80000
0x000c: 0000df13  srli    t5, ra, 0
0x0010: 80000eb7  lui     t4, 0x80000
0x0014: 00200193  addi    gp, x0, 2
0x0018: 29df1863  bne     t5, t4, +656
0x001c: 800000b7  lui     ra, 0x80000
0x0020: 0010df13  srli    t5, ra, 1
0x0024: 40000eb7  lui     t4, 0x40000
0x0028: 00300193  addi    gp, x0, 3
0x002c: 27df1e63  bne     t5, t4, +636
0x0030: 800000b7  lui     ra, 0x80000
0x0034: 0070df13  srli    t5, ra, 7
0x0038: 01000eb7  lui     t4, 0x01000
0x003c: 00400193  addi    gp, x0, 4
0x0040: 27df1463  bne     t5, t4, +616
0x0044: 800000b7  lui     ra, 0x80000
0x0048: 00e0df13  srli    t5, ra, 14
0x004c: 00020eb7  lui     t4, 0x00020
0x0050: 00500193  addi    gp, x0, 5
0x0054: 25df1a63  bne     t5, t4, +596
0x0058: 800000b7  lui     ra, 0x80000
0x005c: 00108093  addi    ra, ra, 1
0x0060: 01f0df13  srli    t5, ra, 31
0x0064: 00100e93  addi    t4, x0, 1
0x0068: 00600193  addi    gp, x0, 6
0x006c: 23df1e63  bne     t5, t4, +572
0x0070: fff00093  addi    ra, x0, -1
0x0074: 0000df13  srli    t5, ra, 0
0x0078: fff00e93  addi    t4, x0, -1
0x007c: 00700193  addi    gp, x0, 7
0x0080: 23df1463  bne     t5, t4, +552
0x0084: fff00093  addi    ra, x0, -1
0x0088: 0010df13  srli    t5, ra, 1
0x008c: 80000eb7  lui     t4, 0x80000
0x0090: fffe8e93  addi    t4, t4, -1
0x0094: 00800193  addi    gp, x0, 8
0x0098: 21df1863  bne     t5, t4, +528
0x009c: fff00093  addi    ra, x0, -1
0x00a0: 0070df13  srli    t5, ra, 7
0x00a4: 02000eb7  lui     t4, 0x02000
0x00a8: fffe8e93  addi    t4, t4, -1
0x00ac: 00900193  addi    gp, x0, 9
0x00b0: 1fdf1c63  bne     t5, t4, +504
0x00b4: fff00093  addi    ra, x0, -1
0x00b8: 00e0df13  srli    t5, ra, 14
0x00bc: 00040eb7  lui     t4, 0x00040
0x00c0: fffe8e93  addi    t4, t4, -1
0x00c4: 00a00193  addi    gp, x0, 10
0x00c8: 1fdf1063  bne     t5, t4, +480
0x00cc: fff00093  addi    ra, x0, -1
0x00d0: 01f0df13  srli    t5, ra, 31
0x00d4: 00100e93  addi    t4, x0, 1
0x00d8: 00b00193  addi    gp, x0, 11
0x00dc: 1ddf1663  bne     t5, t4, +460
0x00e0: 212120b7  lui     ra, 0x21212
0x00e4: 12108093  addi    ra, ra, 289
0x00e8: 0000df13  srli    t5, ra, 0
0x00ec: 21212eb7  lui     t4, 0x21212
0x00f0: 121e8e93  addi    t4, t4, 289
0x00f4: 00c00193  addi    gp, x0, 12
0x00f8: 1bdf1863  bne     t5, t4, +432
0x00fc: 212120b7  lui     ra, 0x21212
0x0100: 12108093  addi    ra, ra, 289
0x0104: 0010df13  srli    t5, ra, 1
0x0108: 10909eb7  lui     t4, 0x10909
0x010c: 090e8e93  addi    t4, t4, 144
0x0110: 00d00193  addi    gp, x0, 13
0x0114: 19df1a63  bne     t5, t4, +404
0x0118: 212120b7  lui     ra, 0x21212
0x011c: 12108093  addi    ra, ra, 289
0x0120: 0070df13  srli    t5, ra, 7
0x0124: 00424eb7  lui     t4, 0x00424
0x0128: 242e8e93  addi    t4, t4, 578
0x012c: 00e00193  addi    gp, x0, 14
0x0130: 17df1c63  bne     t5, t4, +376
0x0134: 212120b7  lui     ra, 0x21212
0x0138: 12108093  addi    ra, ra, 289
0x013c: 00e0df13  srli    t5, ra, 14
0x0140: 00008eb7  lui     t4, 0x00008
0x0144: 484e8e93  addi    t4, t4, 1156
0x0148: 00f00193  addi    gp, x0, 15
0x014c: 15df1e63  bne     t5, t4, +348
0x0150: 212120b7  lui     ra, 0x21212
0x0154: 12108093  addi    ra, ra, 289
0x0158: 01f0df13  srli    t5, ra, 31
0x015c: 00000e93  addi    t4, x0, 0
0x0160: 01000193  addi    gp, x0, 16
0x0164: 15df1263  bne     t5, t4, +324
0x0168: 800000b7  lui     ra, 0x80000
0x016c: 0070d093  srli    ra, ra, 7
0x0170: 01000eb7  lui     t4, 0x01000
0x0174: 01100193  addi    gp, x0, 17
0x0178: 13d09863  bne     ra, t4, +304
0x017c: 00000213  addi    tp, x0, 0
0x0180: 800000b7  lui     ra, 0x80000
0x0184: 0070df13  srli    t5, ra, 7
0x0188: 000f0313  addi    t1, t5, 0
0x018c: 00120213  addi    tp, tp, 1
0x0190: 00200293  addi    t0, x0, 2
0x0194: fe5216e3  bne     tp, t0, -20
0x0198: 01000eb7  lui     t4, 0x01000
0x019c: 01200193  addi    gp, x0, 18
0x01a0: 11d31463  bne     t1, t4, +264
0x01a4: 00000213  addi    tp, x0, 0
0x01a8: 800000b7  lui     ra, 0x80000
0x01ac: 00e0df13  srli    t5, ra, 14
0x01b0: 00000013  addi    x0, x0, 0
0x01b4: 000f0313  addi    t1, t5, 0
0x01b8: 00120213  addi    tp, tp, 1
0x01bc: 00200293  addi    t0, x0, 2
0x01c0: fe5214e3  bne     tp, t0, -24
0x01c4: 00020eb7  lui     t4, 0x00020
0x01c8: 01300193  addi    gp, x0, 19
0x01cc: 0dd31e63  bne     t1, t4, +220
0x01d0: 00000213  addi    tp, x0, 0
0x01d4: 800000b7  lui     ra, 0x80000
0x01d8: 00108093  addi    ra, ra, 1
0x01dc: 01f0df13  srli    t5, ra, 31
0x01e0: 00000013  addi    x0, x0, 0
0x01e4: 00000013  addi    x0, x0, 0
0x01e8: 000f0313  addi    t1, t5, 0
0x01ec: 00120213  addi    tp, tp, 1
0x01f0: 00200293  addi    t0, x0, 2
0x01f4: fe5210e3  bne     tp, t0, -32
0x01f8: 00100e93  addi    t4, x0, 1
0x01fc: 01400193  addi    gp, x0, 20
0x0200: 0bd31463  bne     t1, t4, +168
0x0204: 00000213  addi    tp, x0, 0
0x0208: 800000b7  lui     ra, 0x80000
0x020c: 0070df13  srli    t5, ra, 7
0x0210: 00120213  addi    tp, tp, 1
0x0214: 00200293  addi    t0, x0, 2
0x0218: fe5218e3  bne     tp, t0, -16
0x021c: 01000eb7  lui     t4, 0x01000
0x0220: 01500193  addi    gp, x0, 21
0x0224: 09df1263  bne     t5, t4, +132
0x0228: 00000213  addi    tp, x0, 0
0x022c: 800000b7  lui     ra, 0x80000
0x0230: 00000013  addi    x0, x0, 0
0x0234: 00e0df13  srli    t5, ra, 14
0x0238: 00120213  addi    tp, tp, 1
0x023c: 00200293  addi    t0, x0, 2
0x0240: fe5216e3  bne     tp, t0, -20
0x0244: 00020eb7  lui     t4, 0x00020
0x0248: 01600193  addi    gp, x0, 22
0x024c: 05df1e63  bne     t5, t4, +92
0x0250: 00000213  addi    tp, x0, 0
0x0254: 800000b7  lui     ra, 0x80000
0x0258: 00108093  addi    ra, ra, 1
0x025c: 00000013  addi    x0, x0, 0
0x0260: 00000013  addi    x0, x0, 0
0x0264: 01f0df13  srli    t5, ra, 31
0x0268: 00120213  addi    tp, tp, 1
0x026c: 00200293  addi    t0, x0, 2
0x0270: fe5212e3  bne     tp, t0, -28
0x0274: 00100e93  addi    t4, x0, 1
0x0278: 01700193  addi    gp, x0, 23
0x027c: 03df1663  bne     t5, t4, +44
0x0280: 00405093  srli    ra, x0, 4
0x0284: 00000e93  addi    t4, x0, 0
0x0288: 01800193  addi    gp, x0, 24
0x028c: 01d09e63  bne     ra, t4, +28
0x0290: 02100093  addi    ra, x0, 33
0x0294: 00a0d013  srli    x0, ra, 10
0x0298: 00000e93  addi    t4, x0, 0
0x029c: 01900193  addi    gp, x0, 25
0x02a0: 01d01463  bne     x0, t4, +8
0x02a4: 00301863  bne     x0, gp, +16
0x02a8: 00100d13  addi    s10, x0, 1
0x02ac: 00000d93  addi    s11, x0, 0
0x02b0: 0000006f  j       0              # halt loop
0x02b4: 00100d13  addi    s10, x0, 1
0x02b8: 00100d93  addi    s11, x0, 1
0x02bc: 0000006f  j       0              # halt loop
```

### inst_xori  \[PASS ✅\]

- **ROM 行数：** 162 行（含 NOP 填充），有效指令 129 条
- **指令分布：** ADDI×71, BNE×20, JAL×2, LUI×23, XORI×13

```asm
0x0000: 00000d13  addi    s10, x0, 0
0x0004: 00000d93  addi    s11, x0, 0
0x0008: 00ff10b7  lui     ra, 0x00ff1
0x000c: f0008093  addi    ra, ra, -256
0x0010: f0f0cf13  xori    t5, ra, -241
0x0014: ff00feb7  lui     t4, 0xff00f
0x0018: 00fe8e93  addi    t4, t4, 15
0x001c: 00200193  addi    gp, x0, 2
0x0020: 1ddf1663  bne     t5, t4, +460
0x0024: 0ff010b7  lui     ra, 0x0ff01
0x0028: ff008093  addi    ra, ra, -16
0x002c: 0f00cf13  xori    t5, ra, 240
0x0030: 0ff01eb7  lui     t4, 0x0ff01
0x0034: f00e8e93  addi    t4, t4, -256
0x0038: 00300193  addi    gp, x0, 3
0x003c: 1bdf1863  bne     t5, t4, +432
0x0040: 00ff10b7  lui     ra, 0x00ff1
0x0044: 8ff08093  addi    ra, ra, -1793
0x0048: 70f0cf13  xori    t5, ra, 1807
0x004c: 00ff1eb7  lui     t4, 0x00ff1
0x0050: ff0e8e93  addi    t4, t4, -16
0x0054: 00400193  addi    gp, x0, 4
0x0058: 19df1a63  bne     t5, t4, +404
0x005c: f00ff0b7  lui     ra, 0xf00ff
0x0060: 00f08093  addi    ra, ra, 15
0x0064: 0f00cf13  xori    t5, ra, 240
0x0068: f00ffeb7  lui     t4, 0xf00ff
0x006c: 0ffe8e93  addi    t4, t4, 255
0x0070: 00500193  addi    gp, x0, 5
0x0074: 17df1c63  bne     t5, t4, +376
0x0078: ff00f0b7  lui     ra, 0xff00f
0x007c: 70008093  addi    ra, ra, 1792
0x0080: 70f0c093  xori    ra, ra, 1807
0x0084: ff00feb7  lui     t4, 0xff00f
0x0088: 00fe8e93  addi    t4, t4, 15
0x008c: 00600193  addi    gp, x0, 6
0x0090: 15d09e63  bne     ra, t4, +348
0x0094: 00000213  addi    tp, x0, 0
0x0098: 0ff010b7  lui     ra, 0x0ff01
0x009c: ff008093  addi    ra, ra, -16
0x00a0: 0f00cf13  xori    t5, ra, 240
0x00a4: 000f0313  addi    t1, t5, 0
0x00a8: 00120213  addi    tp, tp, 1
0x00ac: 00200293  addi    t0, x0, 2
0x00b0: fe5214e3  bne     tp, t0, -24
0x00b4: 0ff01eb7  lui     t4, 0x0ff01
0x00b8: f00e8e93  addi    t4, t4, -256
0x00bc: 00700193  addi    gp, x0, 7
0x00c0: 13d31663  bne     t1, t4, +300
0x00c4: 00000213  addi    tp, x0, 0
0x00c8: 00ff10b7  lui     ra, 0x00ff1
0x00cc: 8ff08093  addi    ra, ra, -1793
0x00d0: 70f0cf13  xori    t5, ra, 1807
0x00d4: 00000013  addi    x0, x0, 0
0x00d8: 000f0313  addi    t1, t5, 0
0x00dc: 00120213  addi    tp, tp, 1
0x00e0: 00200293  addi    t0, x0, 2
0x00e4: fe5212e3  bne     tp, t0, -28
0x00e8: 00ff1eb7  lui     t4, 0x00ff1
0x00ec: ff0e8e93  addi    t4, t4, -16
0x00f0: 00800193  addi    gp, x0, 8
0x00f4: 0fd31c63  bne     t1, t4, +248
0x00f8: 00000213  addi    tp, x0, 0
0x00fc: f00ff0b7  lui     ra, 0xf00ff
0x0100: 00f08093  addi    ra, ra, 15
0x0104: 0f00cf13  xori    t5, ra, 240
0x0108: 00000013  addi    x0, x0, 0
0x010c: 00000013  addi    x0, x0, 0
0x0110: 000f0313  addi    t1, t5, 0
0x0114: 00120213  addi    tp, tp, 1
0x0118: 00200293  addi    t0, x0, 2
0x011c: fe5210e3  bne     tp, t0, -32
0x0120: f00ffeb7  lui     t4, 0xf00ff
0x0124: 0ffe8e93  addi    t4, t4, 255
0x0128: 00900193  addi    gp, x0, 9
0x012c: 0dd31063  bne     t1, t4, +192
0x0130: 00000213  addi    tp, x0, 0
0x0134: 0ff010b7  lui     ra, 0x0ff01
0x0138: ff008093  addi    ra, ra, -16
0x013c: 0f00cf13  xori    t5, ra, 240
0x0140: 00120213  addi    tp, tp, 1
0x0144: 00200293  addi    t0, x0, 2
0x0148: fe5216e3  bne     tp, t0, -20
0x014c: 0ff01eb7  lui     t4, 0x0ff01
0x0150: f00e8e93  addi    t4, t4, -256
0x0154: 00a00193  addi    gp, x0, 10
0x0158: 09df1a63  bne     t5, t4, +148
0x015c: 00000213  addi    tp, x0, 0
0x0160: 00ff10b7  lui     ra, 0x00ff1
0x0164: fff08093  addi    ra, ra, -1
0x0168: 00000013  addi    x0, x0, 0
0x016c: 00f0cf13  xori    t5, ra, 15
0x0170: 00120213  addi    tp, tp, 1
0x0174: 00200293  addi    t0, x0, 2
0x0178: fe5214e3  bne     tp, t0, -24
0x017c: 00ff1eb7  lui     t4, 0x00ff1
0x0180: ff0e8e93  addi    t4, t4, -16
0x0184: 00b00193  addi    gp, x0, 11
0x0188: 07df1263  bne     t5, t4, +100
0x018c: 00000213  addi    tp, x0, 0
0x0190: f00ff0b7  lui     ra, 0xf00ff
0x0194: 00f08093  addi    ra, ra, 15
0x0198: 00000013  addi    x0, x0, 0
0x019c: 00000013  addi    x0, x0, 0
0x01a0: 0f00cf13  xori    t5, ra, 240
0x01a4: 00120213  addi    tp, tp, 1
0x01a8: 00200293  addi    t0, x0, 2
0x01ac: fe5212e3  bne     tp, t0, -28
0x01b0: f00ffeb7  lui     t4, 0xf00ff
0x01b4: 0ffe8e93  addi    t4, t4, 255
0x01b8: 00c00193  addi    gp, x0, 12
0x01bc: 03df1863  bne     t5, t4, +48
0x01c0: 0f004093  xori    ra, x0, 240
0x01c4: 0f000e93  addi    t4, x0, 240
0x01c8: 00d00193  addi    gp, x0, 13
0x01cc: 03d09063  bne     ra, t4, +32
0x01d0: 00ff00b7  lui     ra, 0x00ff0
0x01d4: 0ff08093  addi    ra, ra, 255
0x01d8: 70f0c013  xori    x0, ra, 1807
0x01dc: 00000e93  addi    t4, x0, 0
0x01e0: 00e00193  addi    gp, x0, 14
0x01e4: 01d01463  bne     x0, t4, +8
0x01e8: 00301863  bne     x0, gp, +16
0x01ec: 00100d13  addi    s10, x0, 1
0x01f0: 00000d93  addi    s11, x0, 0
0x01f4: 0000006f  j       0              # halt loop
0x01f8: 00100d13  addi    s10, x0, 1
0x01fc: 00100d93  addi    s11, x0, 1
0x0200: 0000006f  j       0              # halt loop
```
