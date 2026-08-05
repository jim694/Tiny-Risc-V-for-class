import sys
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tests.basic_scope import is_basic_applicable


def list_data_files(path):
    return [str(item) for item in sorted(Path(path).glob('*.data'))]


def main():
    sim_dir = Path(__file__).resolve().parent
    data_files = list_data_files(str(ROOT / 'tests' / 'Basic_Inst_Example'))

    anyfail = False
    applicable_count = 0
    na_count = 0

    for file in data_files:
        name = Path(file).name
        if not is_basic_applicable(name):
            print(name + '    N/A (removed DIV/REM instruction)')
            na_count += 1
            continue

        applicable_count += 1
        cmd = [sys.executable, str(sim_dir / 'sim_basic_example.py'), file, 'inst.data']
        result = subprocess.run(cmd, cwd=sim_dir, capture_output=True, text=True, check=False)
        r = result.stdout + result.stderr
        if r.find('TEST_PASS') != -1:
            print(name + '    PASS')
        else:
            print(name + '    !!!FAIL!!!')
            anyfail = True

    if not anyfail:
        print(f'All applicable Basic_Inst_Example PASS ({applicable_count} PASS, {na_count} N/A).')
        return 0
    return 1


if __name__ == '__main__':
    sys.exit(main())
