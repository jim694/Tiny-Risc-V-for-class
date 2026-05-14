"""
UART 接收工具：收集 FPGA 通过 UART TX 发出的所有字节，直到静默超时为止。

用法：
    python uart_recv.py COMx [wait_sec] [idle_sec]

参数：
    COMx      串口号（如 COM3 或 /dev/ttyUSB0）
    wait_sec  等待首字节的最长秒数（默认 15）
    idle_sec  收到首字节后，连续静默多少秒视为结束（默认 1）

示例：
    python uart_recv.py COM3          # 等首字节 15s，静默 1s 后结束
    python uart_recv.py COM3 30 2    # 等首字节 30s，静默 2s 后结束

操作步骤：
    1. 先用 tinyriscv_fw_downloader.py 下载程序
    2. 运行本脚本
    3. 按开发板 Reset 键启动 CPU
"""

import sys
import serial


def main():
    if len(sys.argv) < 2:
        print("Usage: python uart_recv.py COMx [wait_sec] [idle_sec]")
        sys.exit(1)

    port      = sys.argv[1]
    wait_sec  = float(sys.argv[2]) if len(sys.argv) > 2 else 15.0
    idle_sec  = float(sys.argv[3]) if len(sys.argv) > 3 else 1.0

    ser = serial.Serial(
        port     = port,
        baudrate = 115200,
        bytesize = serial.EIGHTBITS,
        parity   = serial.PARITY_NONE,
        stopbits = serial.STOPBITS_ONE,
        timeout  = wait_sec,   # 等待首字节的超时
    )

    print(f"Opened {port} @ 115200 baud")
    print(f"Waiting for first byte (timeout {wait_sec}s)...")
    print(">>> Press RESET on the FPGA board now <<<\n")

    # 等待首字节
    first = ser.read(1)
    if not first:
        print("TIMEOUT: no data received.")
        ser.close()
        sys.exit(1)

    # 首字节到达，切换为短超时收集后续字节
    buf = bytearray(first)
    ser.timeout = idle_sec
    while True:
        chunk = ser.read(64)
        if not chunk:
            break
        buf.extend(chunk)

    ser.close()

    print(f"Received {len(buf)} byte(s):")
    print(f"  HEX : {' '.join(f'{b:02X}' for b in buf)}")
    print(f"  STR : {''.join(chr(b) if 32 <= b < 127 else '.' for b in buf)}")

    # 若只收到 1 字节，自动按温度解读
    if len(buf) == 1:
        raw = buf[0]
        temp_c = raw / 2.0
        print(f"\n  Temperature interpretation: {raw} × 0.5°C = {temp_c:.1f}°C")


if __name__ == "__main__":
    main()