import sys
import subprocess
import shutil
from pathlib import Path


# 用于运行 Basic_Inst_Example / Extend_Inst_Example 中已是 $readmemh 格式的 .data 文件
# 用法: python sim_basic_example.py <path/to/inst_xxx.data> [inst.data]
def main():
    sim_dir = Path(__file__).resolve().parent
    repo_root = sim_dir.parent
    work_dir = sim_dir / '.tmp' / 'data'
    work_dir.mkdir(parents=True, exist_ok=True)

    src = Path(sys.argv[1]).resolve()
    dst = work_dir / (sys.argv[2] if len(sys.argv) > 2 else 'inst.data')

    # 1. 直接将 .data 文件复制为 inst.data（无需 BinToMem 转换）
    shutil.copy2(src, dst)

    # 2. 编译 RTL
    cmd = [sys.executable, str(sim_dir / 'compile_rtl.py'), str(repo_root), str(work_dir)]
    compile_result = subprocess.run(cmd, cwd=work_dir, check=False)
    if compile_result.returncode != 0:
        print('!!!Fail, RTL compile failed!!!')
        return compile_result.returncode

    # 3. 运行仿真
    process = subprocess.Popen(['vvp', 'out.vvp'], cwd=work_dir)
    try:
        process.wait(timeout=20)
    except subprocess.TimeoutExpired:
        print('!!!Fail, vvp exec timeout!!!')
        process.kill()
        process.wait()
        return 1
    return process.returncode


if __name__ == '__main__':
    sys.exit(main())
