import os
import sys


def list_data_files(path):
    files = []
    for name in sorted(os.listdir(path)):
        if name.endswith('.data'):
            files.append(os.path.join(path, name))
    return files


def main():
    data_files = list_data_files(r'../tests/Basic_Inst_Example')

    anyfail = False

    for file in data_files:
        cmd = r'python sim_basic_example.py' + ' ' + file + ' ' + r'inst.data'
        f = os.popen(cmd)
        r = f.read()
        f.close()
        name = os.path.basename(file)
        if r.find('TEST_PASS') != -1:
            print(name + '    PASS')
        else:
            print(name + '    !!!FAIL!!!')
            anyfail = True

    if not anyfail:
        print('Congratulation, All Basic_Inst_Example PASS...')


if __name__ == '__main__':
    sys.exit(main())
