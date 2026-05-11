# TinyRISCV 仿真验证流程

**日期：** 2026-05-11
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）
**工具链：** iverilog 12.0 + vvp + Python 3.11

---

## 1. 环境要求

| 工具 | 版本 | 用途 |
|------|------|------|
| iverilog | 12.0+ | Verilog 编译器 |
| vvp | 12.0+ | 仿真运行器 |
| Python | 3.x | 驱动脚本 |
| gtkwave | 任意 | 波形查看（可选） |

验证安装：

```bash
iverilog -V
vvp -V
python --version
```

---

## 2. 项目目录结构（验证相关部分）

```
Tiny-Risc-V-for-class/
├── rtl/
│   ├── core/        # 处理器核心 RTL（流水线各阶段）
│   ├── perips/      # 外设 RTL（RAM/ROM/UART/SPI/GPIO/Timer）
│   ├── debug/       # JTAG 调试模块
│   ├── soc/         # SoC 顶层（tinyriscv_soc_top.v）
│   └── utils/       # 通用工具模块
├── tb/
│   └── tinyriscv_soc_tb.v   # 顶层 Testbench
├── sim/
│   ├── compile_rtl.py        # 调用 iverilog 编译所有 RTL
│   ├── sim_new_nowave.py     # 主仿真脚本
│   └── test_all_isa.py       # 批量 ISA 回归脚本
├── tests/
│   ├── isa/generated/        # 预编译 ISA 测试 bin 文件（48 个）
│   └── example/              # C 语言例程
└── tools/
    └── BinToMem_CLI.py       # bin → mem 格式转换工具
```

---

## 3. 仿真流程说明

`sim_new_nowave.py` 是主入口，内部依次执行三步：

```
bin 文件
   │
   ▼ tools/BinToMem_CLI.py
mem 文件（inst.data）
   │
   ▼ compile_rtl.py → iverilog
out.vvp（编译产物）
   │
   ▼ vvp out.vvp
终端输出 PASS / FAIL
```

**PASS/FAIL 判定机制：** Testbench 直接探测处理器内部寄存器 `x26`、`x27` 的值。这是 RISC-V 合规测试的标准约定——测试程序结束时，`x27=1` 表示通过，否则失败。

---

## 4. 运行命令

所有命令在 `sim/` 目录下执行。

### 4.1 单条指令测试

```bash
# 路径必须用正斜杠（bash 下反斜杠会被当作转义符）
python sim_new_nowave.py ../tests/isa/generated/rv32ui-p-add.bin inst.data
```

成功输出示例：

```
test running...
WARNING: ../tb/tinyriscv_soc_tb.v:498: $readmemh(inst.data): Not enough words...
~~~~~~~~~~~~~~~~~~~ TEST_PASS ~~~~~~~~~~~~~~~~~~~
...
```

> `$readmemh` 的 WARNING 正常，原因是测试程序比 ROM 空间小，不影响结果。

### 4.2 全量 ISA 回归测试

```bash
python test_all_isa.py
```

成功输出示例（48 条全通过）：

```
../tests/isa/generated\rv32ui-p-add.bin    PASS
../tests/isa/generated\rv32ui-p-addi.bin   PASS
...
../tests/isa/generated\rv32um-p-remu.bin   PASS
Congratulation, All PASS...
```

失败时脚本在第一个 `!!!FAIL!!!` 处停止。

### 4.3 C 语言例程测试

```bash
# 先编译例程（需要 RISC-V GNU 工具链）
cd ../tests/example/simple
make

# 再仿真（回到 sim/ 目录）
cd ../../../sim
python sim_new_nowave.py ../tests/example/simple/simple.bin inst.data
```

---

## 5. 标准 RTL 修改→验证循环

```
1. 修改 rtl/ 下的目标 .v 文件
        │
        ▼
2. cd sim/
   python test_all_isa.py
        │
        ├─ 全 PASS → 回归通过，改动安全
        │
        └─ 有 FAIL → 定位失败指令，检查 RTL 逻辑
```

**基准状态（2026-05-11 验证）：** 48/48 全部 PASS，涵盖 RV32I 和 RV32M 所有指令。

---

## 6. 路径注意事项

在 bash/PowerShell 终端手动传路径时，必须使用**正斜杠**：

```bash
# 正确
python sim_new_nowave.py ../tests/isa/generated/rv32ui-p-add.bin inst.data

# 错误（bash 下反斜杠被吞）
python sim_new_nowave.py ..\tests\isa\generated\rv32ui-p-add.bin inst.data
```

`test_all_isa.py` 内部使用 Python `os.path.join` 构造路径，通过 `os.popen` 调用 cmd.exe 执行，反斜杠可正常识别，无需手动干预。
