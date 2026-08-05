import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SIM_DIR = ROOT / "sim"

if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests.basic_scope import BASIC_STAGE2_CASES


def main():
    data_dir = ROOT / "tests" / "Basic_Inst_Example"
    available = {item.name: item for item in data_dir.glob("*.data")}
    missing = sorted(BASIC_STAGE2_CASES - available.keys())
    if missing:
        for name in missing:
            print(f"{name}    MISSING")
        return 1

    failed = False
    for name in sorted(BASIC_STAGE2_CASES):
        result = subprocess.run(
            [sys.executable, str(SIM_DIR / "sim_basic_example.py"), str(available[name]), "inst.data"],
            cwd=SIM_DIR,
            capture_output=True,
            text=True,
            check=False,
        )
        output = result.stdout + result.stderr
        if "TEST_PASS" in output and result.returncode == 0:
            print(f"{name}    PASS")
        else:
            print(f"{name}    FAIL")
            failed = True

    if failed:
        return 1
    print(f"All Basic_Inst_Example stage2 PASS ({len(BASIC_STAGE2_CASES)}/20).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
