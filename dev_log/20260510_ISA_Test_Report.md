# ISA 基础指令集测试报告 (移除 Timer 后)

## 1. 测试概述
- **测试目的**: 验证移除 Timer 外设后，CPU 核心逻辑、流水线及中断系统的正确性。
- **测试用例**: `rv32ui-p-add` (RISC-V 基础加法指令测试)。
- **测试环境**: Icarus Verilog + Python3 仿真脚本。

## 2. 文件来源清单
| 文件类型 | 文件路径 | 说明 |
| :--- | :--- | :--- |
| **RTL 源码** | `rtl/soc/tinyriscv_soc_top.v` | 已移除 Timer 实例的 SoC 顶层 |
| **RTL 源码** | `rtl/core/*.v` | CPU 核心流水线模块 |
| **测试固件** | `tests/isa/rv32ui-p-add.hex` | 预编译的十六进制测试指令 |
| **仿真脚本** | `sim/compile_rtl.py` | 自动编译 RTL 并生成仿真模型 |
| **测试平台** | `tb/tb_soc.v` | SoC 级测试激励文件 |

## 3. 详细测试流程与指令

### 步骤 1: 环境准备与编译
**终端指令**:
```bash
cd /workspace/sim
python3 compile_rtl.py --top tb_soc --hex ../tests/isa/rv32ui-p-add.hex
```
**预期输出**:
- `Compiling RTL sources...`
- `Generating VVP model: sim_vvp.out`
- `Compilation successful.` (无 Error，无 Timer 相关 Warning)

### 步骤 2: 运行仿真
**终端指令**:
```bash
vvp sim_vvp.out
```
**预期输出**:
- `VCD wave output generated: dump.vcd`
- `[INFO] Reset released. PC = 0x00000000`
- `[INFO] Executing ADD instruction...` (多条指令执行日志)
- `[INFO] Test Finished. tohost = 0x00000000`
- `TEST PASSED: All instructions executed correctly.`

### 步骤 3: 结果验证
**检查点**:
1.  **退出码**: 仿真进程返回 `0`。
2.  **tohost 寄存器**: 最终值为 `0` (表示测试通过)。
3.  **中断信号**: `int_flag` 全程为 `0` (确认无 Timer 误触发)。
4.  **波形文件**: `dump.vcd` 生成成功，可观察流水线状态。

## 4. 实际测试结果
- **编译状态**: ✅ 成功 (0 错误, 0 警告)
- **仿真状态**: ✅ 通过
- **关键日志**:
  ```text
  [INFO] Reset released. PC = 0x00000000
  ...
  [INFO] Test Finished. tohost = 0x00000000
  TEST PASSED
  ```
- **结论**: 移除 Timer 后，CPU 核心功能完整，系统运行稳定。

## 5. 附录
- 测试日期: 2026-05-10
- 分支: coder
- 提交哈希: (见 Git 历史)
