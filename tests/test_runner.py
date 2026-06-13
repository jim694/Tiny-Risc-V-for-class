#!/usr/bin/env python3
"""
TinyRISCV 半自动化测试运行器
整合：固件上传 → Key1 释放 UART → 板上验证 / UART 输出接收 → 人工 pass/fail 输入 → 汇总报告
同一 COM 口全程不关闭，上传后按下并保持 Key1 让程序开始运行。

用法：
    python test_runner.py COM3
    python test_runner.py COM3 --only basic    # 只跑 Basic_Inst_Example
    python test_runner.py COM3 --only extend   # 只跑扩展指令
"""

import os
import sys
import serial
import time
import glob
from datetime import datetime

# ─── 配置 ──────────────────────────────────────────────────────────────────────
BAUD_RATE        = 115200
UPLOAD_PKT_TOUT  = 3      # 每包 ACK 超时（秒）
RECV_WAIT_SEC    = 20     # 释放 UART 后等待首字节最长秒数
RECV_IDLE_SEC    = 1.5    # 静默多久视为接收完成

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# ─── 工具函数（来自 tinyriscv_fw_downloader.py）────────────────────────────────

def calc_crc16(data):
    crc = 0xFFFF
    for pos in data:
        crc ^= pos
        for _ in range(8):
            if crc & 1:
                crc = (crc >> 1) ^ 0xA001
            else:
                crc >>= 1
    return crc


def convert_data_to_bin(data_path):
    """将 ASCII hex .data 文件转为小端二进制 .bin 文件，返回 .bin 路径。"""
    bin_path = data_path + '.bin'
    with open(data_path, 'r') as fp:
        lines = fp.readlines()
    with open(bin_path, 'wb') as fp:
        for line in lines:
            line = line.strip()
            if len(line) < 8:
                continue
            for i in range(4):
                fp.write(int(line[2*(3-i): 2*(3-i)+2], 16).to_bytes(1, 'big'))
    return bin_path


def upload_firmware(ser, data_file):
    """
    上传固件（支持 .data 或已转换的 .bin）。
    返回 True 表示上传成功。
    """
    ACK = bytes([0x6])

    # 判断是否需要先转换
    if data_file.endswith('.data') and not data_file.endswith('.data.bin'):
        bin_file = convert_data_to_bin(data_file)
    elif data_file.endswith('.data.bin') or data_file.endswith('.bin'):
        bin_file = data_file
    else:
        bin_file = data_file  # 直接当 bin 用

    file_size = os.path.getsize(bin_file)
    file_name = os.path.basename(bin_file)
    total_pkts = file_size // 32 + 1
    print(f"  文件: {file_name}  ({file_size} bytes, {total_pkts+1} packets)")

    # ── 包 0：文件名 + 文件大小 ──
    pkt = [0] * 35
    pkt[0] = 0
    for i, c in enumerate(file_name[:24]):
        pkt[1 + i] = ord(c)
    pkt[25] = (file_size >> 24) & 0xFF
    pkt[26] = (file_size >> 16) & 0xFF
    pkt[27] = (file_size >>  8) & 0xFF
    pkt[28] = (file_size >>  0) & 0xFF
    crc = calc_crc16(pkt[1:33])
    pkt[33] = (crc >> 0) & 0xFF
    pkt[34] = (crc >> 8) & 0xFF
    ser.write(bytes(pkt))
    ser.timeout = UPLOAD_PKT_TOUT
    ack = ser.read(1)
    if ack != ACK:
        print(f"  [ERROR] 包0 NACK (got {ack})")
        return False

    # ── 数据包 ──
    with open(bin_file, 'rb') as fp:
        raw = fp.read()
    idx = 0
    remain = file_size
    pkt_no = 1
    while remain > 0:
        chunk_len = min(32, remain)
        pkt = [0] * 35
        pkt[0] = pkt_no
        for j in range(chunk_len):
            pkt[1 + j] = raw[idx + j]
        crc = calc_crc16(pkt[1:33])
        pkt[33] = (crc >> 0) & 0xFF
        pkt[34] = (crc >> 8) & 0xFF
        ser.write(bytes(pkt))
        ack = ser.read(1)
        if ack != ACK:
            print(f"  [ERROR] 包{pkt_no} NACK")
            return False
        idx    += chunk_len
        remain -= chunk_len
        pkt_no += 1
        # 简单进度
        if pkt_no % 10 == 0 or remain == 0:
            print(f"  上传进度: {pkt_no}/{total_pkts+1}", end='\r')

    print(f"  上传完成: {pkt_no} packets OK          ")
    return True


def recv_uart_output(ser, wait_sec=RECV_WAIT_SEC, idle_sec=RECV_IDLE_SEC):
    """等待并接收 UART 输出，返回 bytearray。"""
    ser.timeout = wait_sec
    first = ser.read(1)
    if not first:
        return bytearray()
    buf = bytearray(first)
    ser.timeout = idle_sec
    while True:
        chunk = ser.read(64)
        if not chunk:
            break
        buf.extend(chunk)
    return buf


def decode_output(buf, output_type):
    """将接收字节解码为人类可读结果。"""
    hex_str = ' '.join(f'{b:02X}' for b in buf)
    asc_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in buf)
    lines = [f"    HEX : {hex_str}", f"    STR : {asc_str}"]
    if output_type == 'temp' and len(buf) >= 1:
        lines.append(f"    温度 : {buf[0] * 0.5:.1f} °C  (raw={buf[0]})")
    elif output_type == 'fire' and len(buf) >= 1:
        lines.append(f"    发放膜电位 : {buf[0]}  (0x{buf[0]:02X})")
    elif output_type == 'sid':
        lines.append(f"    学号字符串 : {asc_str.strip()}")
    return '\n'.join(lines)


# ─── 测试用例定义 ──────────────────────────────────────────────────────────────

def discover_basic_cases():
    """自动发现 Basic_Inst_Example 下所有 .data 文件。"""
    pattern = os.path.join(SCRIPT_DIR, 'Basic_Inst_Example', '*.data')
    files = sorted(f for f in glob.glob(pattern) if not f.endswith('.bin'))
    cases = []
    for f in files:
        name = os.path.splitext(os.path.basename(f))[0]  # e.g. "inst_add"
        cases.append({
            'group':      'Basic_Inst_Example',
            'name':       name,
            'data_file':  f,
            'has_output': False,
            'output_type': None,
            'hint':       '检查仿真波形或板上 LED/调试口寄存器值是否符合预期',
        })
    return cases


EXTEND_CASES = [
    {
        'group':       'Extend_Inst_Example',
        'name':        'sID',
        'data_file':   os.path.join(SCRIPT_DIR, 'Extend_Inst_Example', 'sID', 'sID_inst.data'),
        'has_output':  True,
        'output_type': 'sid',
        'hint':        '应通过 UART 收到学号字符串（10字节 ASCII）',
    },
    {
        'group':       'Extend_Inst_Example',
        'name':        'Temp (RT)',
        'data_file':   os.path.join(SCRIPT_DIR, 'Extend_Inst_Example', 'Temp', 'Temp.data'),
        'has_output':  True,
        'output_type': 'temp',
        'hint':        '应通过 UART 收到 1 字节温度（×0.5°C）',
    },
    {
        'group':       'Extend_Inst_Example',
        'name':        'IF2 (IF)',
        'data_file':   os.path.join(SCRIPT_DIR, 'Extend_Inst_Example', 'IF2', 'IF2_inst.data'),
        'has_output':  True,
        'output_type': 'fire',
        'hint':        '应通过 UART 收到 1 字节发放膜电位（138=0x8A），然后 CPU 死循环',
    },
]

OTHER_CASES = [
    {
        'group':       'Other_Example',
        'name':        'PWM',
        'data_file':   os.path.join(SCRIPT_DIR, 'Other_Example', 'PWM', 'PWM_inst.data'),
        'has_output':  False,
        'output_type': None,
        'hint':        '用示波器或逻辑分析仪确认 PWM 引脚有正确占空比波形',
    },
]


# ─── 测试执行 ──────────────────────────────────────────────────────────────────

def sep(char='─', width=60):
    print(char * width)


def run_test(ser, case, idx, total):
    """执行单个测试用例，返回 'pass' / 'fail' / 'skip'。"""
    sep()
    print(f"[{idx}/{total}] {case['group']} / {case['name']}")
    sep('·')

    # 1. 检查文件是否存在
    if not os.path.exists(case['data_file']):
        print(f"  [SKIP] 数据文件不存在: {case['data_file']}")
        return 'skip'

    # 2. 上传固件
    print("  >>> 正在上传固件...")
    ok = upload_firmware(ser, case['data_file'])
    if not ok:
        print("  [FAIL] 上传失败")
        return 'fail'

    # 3. 提示释放 UART 并开始运行
    if case['has_output']:
        print(f"\n  验证提示: {case['hint']}")
        input("  >>> 请按下并保持 Key1（释放 UART，CPU 开始运行）后，按 Enter 继续...")
        print(f"  正在接收 UART 输出（最长等待 {RECV_WAIT_SEC}s）...")
        buf = recv_uart_output(ser)
        if not buf:
            print("  [WARN] 未收到 UART 输出（超时）")
        else:
            print(f"\n  收到 {len(buf)} 字节:")
            print(decode_output(buf, case['output_type']))
    else:
        print(f"\n  验证提示: {case['hint']}")
        print("  >>> 请按下并保持 Key1（释放 UART，CPU 开始运行），观察板上现象...")
        input("  （按 Enter 继续）")

    # 4. 人工 pass/fail
    print()
    while True:
        ans = input("  该测试 [p=pass / f=fail / s=skip]: ").strip().lower()
        if ans in ('p', 'pass'):
            return 'pass'
        elif ans in ('f', 'fail'):
            return 'fail'
        elif ans in ('s', 'skip'):
            return 'skip'
        print("  请输入 p / f / s")


# ─── 主程序 ────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        print("Usage: python test_runner.py COMx [--only basic|extend|other]")
        sys.exit(1)

    port   = sys.argv[1]
    filter_group = None
    if '--only' in sys.argv:
        idx = sys.argv.index('--only')
        if idx + 1 < len(sys.argv):
            filter_group = sys.argv[idx + 1].lower()

    # 构建测试列表
    all_cases = discover_basic_cases() + OTHER_CASES + EXTEND_CASES
    if filter_group == 'basic':
        cases = [c for c in all_cases if 'Basic' in c['group']]
    elif filter_group == 'extend':
        cases = [c for c in all_cases if 'Extend' in c['group']]
    elif filter_group == 'other':
        cases = [c for c in all_cases if 'Other' in c['group']]
    else:
        cases = all_cases

    if not cases:
        print("没有找到测试用例。")
        sys.exit(1)

    sep('═')
    print(f"TinyRISCV 测试运行器  |  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print(f"串口: {port} @ {BAUD_RATE} baud  |  共 {len(cases)} 个测试用例")
    sep('═')

    # 打开串口
    try:
        ser = serial.Serial(
            port=port, baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE, xonxoff=False,
            rtscts=False, dsrdtr=False, timeout=UPLOAD_PKT_TOUT,
        )
    except serial.SerialException as e:
        print(f"[ERROR] 无法打开串口 {port}: {e}")
        sys.exit(1)

    print(f"串口已打开: {port}\n")

    # 运行测试
    results = []
    for i, case in enumerate(cases, 1):
        result = run_test(ser, case, i, len(cases))
        results.append((case, result))
        time.sleep(0.5)

    ser.close()

    # 汇总报告
    sep('═')
    print(f"测试结果汇总  ({datetime.now().strftime('%H:%M:%S')})")
    sep()
    passed = failed = skipped = 0
    for case, result in results:
        icon = {'pass': '✓', 'fail': '✗', 'skip': '○'}.get(result, '?')
        print(f"  {icon} [{result.upper():4}]  {case['group']}/{case['name']}")
        if result == 'pass':   passed  += 1
        elif result == 'fail': failed  += 1
        else:                  skipped += 1
    sep()
    print(f"  PASS: {passed}  FAIL: {failed}  SKIP: {skipped}  TOTAL: {len(results)}")
    sep('═')

    # 保存报告
    report_path = os.path.join(SCRIPT_DIR, f"test_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    with open(report_path, 'w', encoding='utf-8') as fp:
        fp.write(f"TinyRISCV Test Report  {datetime.now()}\n")
        fp.write(f"Port: {port}\n\n")
        for case, result in results:
            fp.write(f"[{result.upper():4}] {case['group']}/{case['name']}\n")
        fp.write(f"\nPASS={passed} FAIL={failed} SKIP={skipped}\n")
    print(f"报告已保存: {report_path}")


if __name__ == '__main__':
    main()
