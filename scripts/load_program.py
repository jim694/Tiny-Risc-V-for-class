#!/usr/bin/env python3
"""
load_program.py  —  将 .data 文件烧入 fpga_mem_bridge.v 的 ROM（$readmemh 方式）

用法：
    python scripts/load_program.py <path/to/xxx_inst.data>

示例：
    python scripts/load_program.py tests/Other_Example/PWM/PWM_inst.data
    python scripts/load_program.py tests/Basic_Inst_Example/inst.data

脚本会：
  1. 读取 .data 文件，补全到 256 个字（不足部分填 0）
  2. 将补全后的文件写到 rtl/bridge/rom_init.data（供 $readmemh 使用）
  3. 确保 fpga_mem_bridge.v 中有正确的 $readmemh 初始化块

Vivado 综合时会在 RTL 源文件所在目录搜索 $readmemh 的文件，
因此 rom_init.data 放在 rtl/bridge/ 下即可被正确找到。
"""

import sys
import os
import shutil

ROM_SIZE  = 256
BRIDGE_V  = os.path.join(os.path.dirname(__file__),
                         '..', 'rtl', 'bridge', 'fpga_mem_bridge.v')
ROM_DATA  = os.path.join(os.path.dirname(__file__),
                         '..', 'rtl', 'bridge', 'rom_init.data')

MARKER_BEGIN = '// <<ROM_INIT_BEGIN>>'
MARKER_END   = '// <<ROM_INIT_END>>'


def load_data(path):
    words = []
    with open(path, 'r') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('//'):
                words.append(int(line, 16))
    if len(words) > ROM_SIZE:
        raise ValueError(f'程序 {len(words)} 条指令，超过 ROM 容量 {ROM_SIZE}')
    # 补全到 ROM_SIZE
    words += [0] * (ROM_SIZE - len(words))
    return words


def write_rom_data(words, src_name):
    with open(ROM_DATA, 'w') as f:
        f.write(f'// 由 load_program.py 自动生成，源文件: {src_name}\n')
        for w in words:
            f.write(f'{w:08X}\n')
    print(f'已写入 rtl/bridge/rom_init.data（{len(words)} 个字）')


def gen_init_block(src_name):
    lines = [
        MARKER_BEGIN,
        f'    // 由 load_program.py 自动生成，源文件: {src_name}',
        '    initial begin',
        '        $readmemh("rom_init.data", _rom);',
        '    end',
        MARKER_END,
    ]
    return '\n'.join(lines)


def patch_bridge(src_name):
    with open(BRIDGE_V, 'r', encoding='utf-8') as f:
        src = f.read()

    new_block = gen_init_block(src_name)

    begin_idx = src.find(MARKER_BEGIN)
    end_idx   = src.find(MARKER_END)

    if begin_idx != -1 and end_idx != -1:
        patched = src[:begin_idx] + new_block + src[end_idx + len(MARKER_END):]
    else:
        patched = src.replace('\nendmodule', '\n' + new_block + '\n\nendmodule', 1)

    with open(BRIDGE_V, 'w', encoding='utf-8') as f:
        f.write(patched)
    print('已更新 rtl/bridge/fpga_mem_bridge.v（$readmemh 方式）')


def main():
    if len(sys.argv) < 2:
        print('用法: python scripts/load_program.py <path/to/xxx_inst.data>')
        sys.exit(1)

    data_path = sys.argv[1]
    if not os.path.isfile(data_path):
        print(f'错误: 找不到文件 {data_path}')
        sys.exit(1)

    words    = load_data(data_path)
    src_name = os.path.basename(data_path)
    print(f'已读取 {sum(1 for w in words if w != 0)} 条有效指令（ROM 容量 {ROM_SIZE}）')

    write_rom_data(words, src_name)
    patch_bridge(src_name)

    print()
    print('下一步：')
    print('  1. 在 Vivado 项目中确认 rtl/bridge/rom_init.data 已加入 Sources（Add Sources）')
    print('  2. Reset Run（synth_1）→ Launch Run → 重新生成比特流')


if __name__ == '__main__':
    main()