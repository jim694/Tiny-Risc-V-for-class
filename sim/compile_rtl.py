import sys
import subprocess
from pathlib import Path


# 主函数
def main():
    rtl_dir = Path(sys.argv[1]).resolve()
    output_dir = Path(sys.argv[2]).resolve() if len(sys.argv) > 2 else rtl_dir / 'sim/.tmp/rtl'
    output_dir.mkdir(parents=True, exist_ok=True)
    tb_file = rtl_dir / 'tb' / 'tinyriscv_soc_tb.v'

    # iverilog程序
    iverilog_cmd = ['iverilog']
    # 顶层模块
    #iverilog_cmd += ['-s', r'tinyriscv_soc_tb']
    # 编译生成文件
    iverilog_cmd += ['-o', str(output_dir / 'out.vvp')]
    # 头文件(defines.v)路径
    iverilog_cmd += ['-I', str(rtl_dir / 'rtl/core')]
    iverilog_cmd += ['-I', str(rtl_dir / 'tb')]
    # 宏定义，仿真输出文件
    iverilog_cmd += ['-D', r'OUTPUT="signature.output"']
    # testbench文件
    iverilog_cmd.append(str(tb_file))
    # ../rtl/core
    for relative_path in (
        'rtl/core/ctrl.v', 'rtl/core/custom_unit.v', 'rtl/core/defines.v',
        'rtl/core/ex.v', 'rtl/core/id.v', 'rtl/core/id_ex.v',
        'rtl/core/if_id.v', 'rtl/core/pc_reg.v', 'rtl/core/regs.v',
        'rtl/core/rib.v', 'rtl/core/tinyriscv.v',
    ):
        iverilog_cmd.append(str(rtl_dir / relative_path))
    # ../rtl/cluster
    iverilog_cmd.append(str(rtl_dir / 'rtl/cluster/tinyriscv_cluster.v'))
    # ../rtl/perips
    for relative_path in ('rtl/perips/uart.v', 'rtl/perips/pwm.v', 'rtl/perips/i2c.v'):
        iverilog_cmd.append(str(rtl_dir / relative_path))
    # ../rtl/bridge
    iverilog_cmd.append(str(rtl_dir / 'rtl/bridge/rib_mem_bridge.v'))
    iverilog_cmd.append(str(rtl_dir / 'rtl/bridge/fpga_mem_bridge.v'))
    # ../rtl/debug
    iverilog_cmd.append(str(rtl_dir / 'rtl/debug/uart_debug.v'))
    # ../rtl/soc
    iverilog_cmd.append(str(rtl_dir / 'rtl/soc/tinyriscv_soc_top.v'))
    # ../fpga
    iverilog_cmd.append(str(rtl_dir / 'rtl/soc/tinyriscv_fpga_top.v'))
    # ../rtl/utils
    iverilog_cmd.append(str(rtl_dir / 'rtl/utils/gen_dff.v'))

    # 编译
    process = subprocess.run(iverilog_cmd, check=False)
    return process.returncode

if __name__ == '__main__':
    sys.exit(main())
