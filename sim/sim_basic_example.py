import sys
import shutil
import subprocess
import os


# 用于运行 Basic_Inst_Example / Extend_Inst_Example 中已是 $readmemh 格式的 .data 文件
# 用法: python sim_basic_example.py <path/to/inst_xxx.data> [inst.data]
def main():
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else r'inst.data'

    # 1. 直接将 .data 文件复制为 inst.data（无需 BinToMem 转换）
    shutil.copy(src, dst)

    # 2. 编译 RTL
    cmd = r'python compile_rtl.py ..'
    f = os.popen(cmd)
    f.close()

    # 3. 运行仿真
    vvp_cmd = [r'vvp', r'out.vvp']
    process = subprocess.Popen(vvp_cmd)
    try:
        process.wait(timeout=20)
    except subprocess.TimeoutExpired:
        print('!!!Fail, vvp exec timeout!!!')


if __name__ == '__main__':
    sys.exit(main())
