# Stage2 工程交接总结

更新时间：2026-08-05

## 1. 基线与工作区

- Git 仓库：`Tiny-Risc-V-for-class`
- 当前主要开发分支：`codex`
- 结构整理对照基线：Git tag `v1.1`
- Python 环境要求：`ai_dev_2026`
- 主 Vivado 工程：仓库外的 `../tiny_risc_v_vivado/tiny_risc_v_vivado.xpr`

`v1.1` 中 `fpga/` 主要保存 XDC、开发板说明和图片；tag 中没有
`fpga/tinyriscv_fpga_top.v`。当前 FPGA wrapper 已放在
`rtl/soc/tinyriscv_fpga_top.v`。

工作区仍有较多未提交修改和用户新增文档。不要使用 destructive Git
命令覆盖这些内容。

## 2. 当前处理器结构

当前 FPGA/SoC 的有效层次为：

```text
tinyriscv_fpga_top
├── u_soc : tinyriscv_soc_top
│   └── u_tinyriscv : tinyriscv_cluster
│       ├── u_core : tinyriscv
│       └── u_regs : regs
└── u_fpga_mem_bridge : fpga_mem_bridge
```

当前只实例化本组一个处理器。`tinyriscv_cluster` 保留未来四组对接边界，
但没有实例化另外三个处理器。

`chip_sel[2:0]` 约定：

```text
000 -> 选择本组 core，selected_o = 0001
001/010/011 -> 空槽，selected_o = 0000
100~111 -> 空槽，selected_o = 0000
```

空槽时唯一 core 保持低有效复位，不产生寄存器写入或总线请求。

四组共享资源目前只保留接口边界，实际当前设计使用：

- 1 个 `tinyriscv`；
- 1 组共享 `regs`；
- 1 条 RIB/存储器/外设路径；
- UART、UART debug、PWM、I2C。

## 3. 资源删减状态

当前 active RTL 已删除/移除使用：

- CSR、CLINT、异常/中断路径；
- JTAG debug 路径；
- M 扩展乘法；
- D 扩展除法和余数；
- timer、SPI、GPIO；
- 旧的 DIV/REM 状态机和相关 decode。

历史模块文件仍可能保留在磁盘中，例如：

```text
rtl/core/clint.v
rtl/core/csr_reg.v
rtl/core/div.v
rtl/debug/jtag_*.v
rtl/perips/timer.v
rtl/perips/spi.v
rtl/perips/gpio.v
```

它们不属于当前 active filelist，除非后续明确恢复功能，不要重新加入主工程。

## 4. 目录职责

```text
rtl/
├── core/       # 处理器流水线、regs、defines 和保留的历史模块
├── cluster/    # 当前单 core + shared regs 集成边界
├── soc/        # SoC 顶层、FPGA wrapper、VIO smoke wrapper
├── bridge/     # RIB/FPGA 存储桥
├── perips/     # UART、PWM、I2C 及历史外设
├── debug/      # UART debug 及历史 JTAG
└── utils/      # gen_dff、握手和同步工具

fpga/
├── tinyriscv_soc_top.xdc       # 当前主工程使用的 XDC
├── constrs/tinyriscv.xdc       # 历史/备用约束
├── images/                     # Vivado/开发板说明图片
└── README.md

scripts/
├── load_program.py
├── gen_decode_doc.py
└── vivado/                     # Vivado Tcl 脚本

sim/
├── compile_rtl.py
├── sim_basic_example.py
├── test_basic_example_stage2.py
├── README.md
└── archive/legacy_isa/         # 旧 ISA/compliance runner

tb/
├── tinyriscv_soc_tb.v          # 当前 SoC 程序仿真 TB
├── tinyriscv_cluster_tb.v      # cluster 选择/复位自检
├── core_select_tb.v            # 保留的 core_select 单元 TB
└── archive/legacy_compliance/

tests/
├── Basic_Inst_Example/          # 当前处理器正确性门槛
├── Extend_Inst_Example/         # 扩展程序样例
├── Other_Example/               # PWM/LED 等样例
├── example/                     # 历史程序样例
├── isa/                         # 历史 ISA 生成测试
└── riscv-compliance/            # 历史 compliance 资源
```

## 5. 当前正确性流程

### 5.1 Basic stage2 全量测试

从仓库根目录执行：

```powershell
conda run -n ai_dev_2026 python sim/test_basic_example_stage2.py
```

stage2 固定测试 20 个 RV32I `.data` 文件：

```text
inst_add, inst_andi, inst_auipc, inst_beq, inst_bge,
inst_bgeu, inst_blt, inst_bltu, inst_bne, inst_jal,
inst_jalr, inst_lui, inst_ori, inst_simple, inst_slli,
inst_slti, inst_sltiu, inst_srai, inst_srli, inst_xori
```

预期输出：

```text
All Basic_Inst_Example stage2 PASS (20/20).
```

DIV/REM 文件不再进入 stage2 清单，不输出 N/A：

```text
inst_div.data
inst_divu.data
inst_rem.data
inst_remu.data
```

### 5.2 单条 `.data` 测试

```powershell
conda run -n ai_dev_2026 python sim/sim_basic_example.py tests/Basic_Inst_Example/inst_add.data
```

Extend/Other 中的 `$readmemh` 格式 `.data` 也可以使用同一入口。

### 5.3 测试分工

- `tests/`：提供程序和数据，不负责启动仿真；
- `tb/`：提供 Verilog testbench；
- `sim/`：负责编译 RTL、复制 `.data`、启动 `vvp` 并解析 PASS。

因此当前 Icarus 流程仍需要 `sim/`，但它只是流程封装；Vivado XSim 可以
直接使用 `tb/` 和工程 filelist。

## 6. 仿真产物规则

所有当前 Icarus 产物写入专用临时目录：

```text
sim/.tmp/data/
├── inst.data
├── out.vvp
└── tinyriscv_soc_tb.vcd

sim/.tmp/rtl/
└── out.vvp
```

`sim/.tmp/` 已加入 `sim/.gitignore`。`compile_rtl.py` 支持第二个参数指定
输出目录；未指定时默认使用 `sim/.tmp/rtl/`。不要把 `out.vvp`、`inst.data`
或 VCD 写回 `sim/`、`tb/`、`tests/`。

Vivado 的 `.runs`、`.sim`、`.cache` 等生成目录之前已清理。主工程目录目前
只保留 `tiny_risc_v_vivado.xpr`，再次综合时 Vivado 会重新生成这些目录。

## 7. Vivado/VIO 状态

Vivado Tcl 位于：

```text
scripts/vivado/
```

主 `.xpr` 中 FPGA top 路径已更新为：

```text
rtl/soc/tinyriscv_fpga_top.v
```

已存在的脚本包括：

- `update_vivado_reduced.tcl`：更新主工程 filelist；
- `verify_main_vivado.tcl`：主工程 synthesis/implementation/bitstream；
- `verify_main_xsim.tcl`：主工程 XSim compile/elaborate；
- `create_reduced_vivado_project.tcl`：创建独立验证工程；
- `verify_reduced_xsim.tcl`：独立工程 XSim；
- `vivado_vio_smoke.tcl`：独立 VIO smoke 流程。

VIO 目前只是辅助 smoke 验证，不是处理器正确性门槛。VIO wrapper 位于
`rtl/soc/vio_smoke_top.v`。

此前已验证过主 Vivado 工程 synthesis、implementation、route、DRC 和
bitstream；最近的目录移动只改变了源文件路径，`.xpr` 已同步到新路径，
后续如需重新确认应先运行 `update_vivado_reduced.tcl`，再 reset runs 后综合。

## 8. 已验证结果

最近一次整理前后的有效结果：

- Basic stage2：20/20 PASS；
- scope、资源和控制结构测试：18 项 PASS；
- RTL compile：通过；
- cluster 选择/空槽复位 TB：通过；
- `git diff --check`：通过；
- 临时文件扫描：源码目录外没有 `.vvp/.vcd/.log/.jou/.dmp` 残留，
  预期产物只在 `sim/.tmp/`。

## 9. 后续建议

1. 下一个对话优先运行 `test_basic_example_stage2.py`，确认环境和路径。
2. 组员接入各自处理器时，替换 `rtl/cluster/tinyriscv_cluster.v` 中的
   `u_core`，保持 shared `regs` 和对外 RIB 接口不变。
3. 如果恢复四组切换，再重新引入 `core_select` 和对应的四个 core wrapper；
   当前不要因为 VIO smoke 而提前实例化空处理器。
4. 不要使用 `sim/archive/legacy_isa/` 或 `tests/isa`、`tests/example` 作为
   当前 reduced RTL 的正确性门槛。
5. 保留用户新增的 `doc/` 和 `dev_log/` 内容，不要用 Git 清理命令覆盖工作区。
