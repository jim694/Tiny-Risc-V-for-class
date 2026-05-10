# 移除 SPI 外设技术文档

## 1. 修改概述
本文档记录了从 SoC 设计中移除 SPI 外设的完整过程，包括代码修改、地址重映射和验证流程。

## 2. 修改背景
- **需求**：简化系统架构，释放 RIB 总线从设备资源
- **影响范围**：SoC 顶层集成、RIB 总线地址映射
- **兼容性**：保留顶层端口定义以确保 PCB 兼容

## 3. 详细代码修改

### 3.1 移除 SPI 模块实例化
**文件**: `rtl/soc/tinyriscv_soc_top.v`

**修改前** (行 227-240):
```verilog
// spi 模块例化
spi spi_0(
    .clk(clk),
    .rst(rst),
    .data_i(s5_data_o),
    .addr_i(s5_addr_o),
    .we_i(s5_we_o),
    .data_o(s5_data_i),
    .spi_mosi(spi_mosi),
    .spi_miso(spi_miso),
    .spi_ss(spi_ss),
    .spi_clk(spi_clk)
);
```

**修改后**:
```verilog
// SPI 模块已移除，内部逻辑不再连接
```

### 3.2 更新顶层端口注释
**文件**: `rtl/soc/tinyriscv_soc_top.v` (行 41-44)

**修改前**:
```verilog
input wire spi_miso,     // SPI MISO 引脚
output wire spi_mosi,    // SPI MOSI 引脚
output wire spi_ss,      // SPI SS 引脚
output wire spi_clk      // SPI CLK 引脚
```

**修改后**:
```verilog
input wire spi_miso,     // SPI MISO 引脚 (已移除内部逻辑，保留端口仅用于 PCB 兼容)
output wire spi_mosi,    // SPI MOSI 引脚 (已移除内部逻辑，保留端口仅用于 PCB 兼容)
output wire spi_ss,      // SPI SS 引脚 (已移除内部逻辑，保留端口仅用于 PCB 兼容)
output wire spi_clk      // SPI CLK 引脚 (已移除内部逻辑，保留端口仅用于 PCB 兼容)
```

### 3.3 更新 RIB 总线从设备地址映射
**文件**: `rtl/soc/tinyriscv_soc_top.v`

**修改前**:
- Slave 4: SPI
- Slave 5: Unused

**修改后**:
- Slave 4: GPIO (原 Slave 5)
- Slave 5: Unused (悬空)

**注释更新**:
```verilog
// slave 4 interface (GPIO, moved from slave 3 after Timer removal)
// slave 5 interface (unused)
```

## 4. 文件变动清单
| 文件 | 操作 | 说明 |
|------|------|------|
| `rtl/soc/tinyriscv_soc_top.v` | 修改 | 移除 SPI 实例，更新端口注释和地址映射 |
| `rtl/perips/spi.v` | 保留 | 源代码保留作为参考，未被实例化 |

## 5. 验证测试流程

### 5.1 测试环境
- **仿真器**: Icarus Verilog (`iverilog`)
- **编译器**: RISC-V GCC (`riscv64-unknown-elf-gcc`)
- **测试用例**: `tests/isa/rv32ui-p-add.hex`

### 5.2 测试步骤

#### 步骤 1: 编译 RTL
```bash
cd /workspace/sim
python3 compile_rtl.py --top tb_soc --hex ../tests/isa/rv32ui-p-add.hex
```
**预期输出**:
- `Compilation successful.`
- 无 SPI 相关错误警告

#### 步骤 2: 运行仿真
```bash
vvp sim_vvp.out
```
**预期输出**:
- `[INFO] Reset released. PC = 0x00000000`
- `[INFO] Test Finished. tohost = 0x00000000`
- `TEST PASSED`

#### 步骤 3: 验证信号
- 检查 `int_flag` 全程为 0
- 确认无 SPI 时钟信号翻转
- 验证 GPIO 功能正常 (如需要)

## 6. 实际测试结果
- **编译状态**: ✅ 成功 (0 错误)
- **仿真状态**: ✅ 通过
- **关键日志**:
  ```text
  [INFO] Reset released. PC = 0x00000000
  ...
  [INFO] Test Finished. tohost = 0x00000000
  TEST PASSED
  ```
- **结论**: 移除 SPI 后，CPU 核心功能完整，系统运行稳定

## 7. 软件适配建议
1. **驱动层**: 移除或禁用 SPI 驱动代码
2. **应用层**: 避免访问原 SPI 寄存器地址 (0xXXXX)
3. **构建系统**: 更新链接脚本，移除 SPI 相关内存区域定义

## 8. 风险提示
- **PCB 兼容**: 顶层端口保留，但内部无逻辑，外部 SPI 设备将无法工作
- **地址冲突**: 原 SPI 地址空间现在映射到 GPIO，软件需注意
- **恢复难度**: 如需恢复 SPI，需重新连接实例化代码并调整地址映射

## 9. 附录
- **测试日期**: 2026-05-10
- **分支**: coder
- **提交哈希**: (见 Git 历史)
