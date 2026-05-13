# UART 固件下载 stall 修复

**日期：** 2026-05-13  
**项目：** Tiny-Risc-V-for-class（RV32IM 三级流水线处理器核）

---

## 一、问题描述

通过 `tests/tinyriscv_fw_downloader.py` 向 FPGA 下载程序后，处理器执行结果始终错误（有 `over` 信号但无 `succ` 信号）。切换不同程序重新下载也无法恢复正常。

早期上板验证通过的 PWM 程序，实际上是由 `load_program.py` 在综合时通过 `initial` 块将程序烧入 ROM，并非 UART 下载的功劳。

---

## 二、根本原因

### 2.1 时序不匹配

`uart_debug` 在 `S_WRITE_MEM` 状态下**每个时钟周期推进一个字**：

```verilog
S_WRITE_MEM: begin
    mem_addr_o  <= write_mem_addr;
    mem_wdata_o <= write_mem_data;
    mem_we_o    <= 1'b1;
    // 同时：
    write_mem_addr <= write_mem_addr + 4;   // 下一拍地址+4
end
```

而 `rib_mem_bridge` 每次事务需要 **8 个时钟周期**（S_IDLE → S_SEND_ADDR → S_DATA0～S_DATA3 → S_LATCH）。

| 时钟周期 | uart_debug | rib_mem_bridge |
|---------|-----------|----------------|
| T+0 | 写地址 A，数据 D0 | S_IDLE：捕获 addr=A, wdata=D0，启动事务 |
| T+1 | 写地址 A+4，数据 D1 | S_SEND_ADDR |
| T+2 | 写地址 A+8，数据 D2 | S_DATA0 |
| ... | ... | ... |
| T+7 | 写完全部 8 个字，已进入 S_SEND_ACK | S_LATCH：完成第一个字 |
| T+8 | 写 UART TX（地址切换到 0x3000000c）| S_IDLE：检测不到 ROM 写请求 |

每个 35 字节包含 8 个字，`uart_debug` 在 8 拍内写完，`rib_mem_bridge` 仅能处理第 1 个字，**剩余 7 个字全部丢失**。

### 2.2 为何之前未发现

- 早期仿真用 `$readmemh` 直接将程序加载进仿真内存，绕过了写路径
- 上板 PWM 验证用的是 `initial` 块预烧方式，同样不经过 bridge 写路径
- UART 写路径从未被真正验证过

---

## 三、修复方案

### 3.1 给 uart_debug 添加 `stall_i` 端口

在 `rtl/debug/uart_debug.v` 的模块端口中新增：

```verilog
input wire stall_i,   // 总线暂停：高电平时冻结所有状态推进
```

将所有 13 个 `always` 块的 `else begin` 改为 `else if (!stall_i) begin`：

```verilog
always @ (posedge clk) begin
    if (rst == 1'b0 || debug_en_i == 1'b0) begin
        // 复位逻辑（不受 stall 影响）
    end else if (!stall_i) begin   // ← 新增：stall 期间保持寄存器值
        case (state)
            // 状态机正常推进
        endcase
    end
end
```

效果：当 bridge 处于事务中（`mem_bridge_stall=1`）时，uart_debug 的 `state`、`write_mem_addr`、`write_mem_data` 等所有寄存器保持当前值，不推进到下一个字。

### 3.2 SoC Top 连线

在 `rtl/soc/tinyriscv_soc_top.v` 的 uart_debug 例化中添加：

```verilog
.stall_i(mem_bridge_stall),
```

### 3.3 修复后的时序

```
uart_debug 在 S_WRITE_MEM：
  T+0：驱动 addr=A, data=D0 → bridge 启动，stall=1
  T+1～T+7：stall=1，uart_debug 保持 addr=A, data=D0 不变
  T+8：stall=0（free cycle），uart_debug 推进到下一字 addr=A+4

  T+9：驱动 addr=A+4, data=D1 → bridge 启动下一事务 ...
```

每个字正确写入，8 个字全部写入后 uart_debug 进入 S_SEND_ACK。

---

## 四、为何对 UART 接收没有影响

uart_debug 在接收阶段（`S_WAIT_BYTE/S_WAIT_BYTE2`）轮询 UART 状态寄存器（访问 slave_3）。此时 bridge 在做 ROM 取指，`stall_o` 在每 ~9 个周期中有 1 个周期为 0（free cycle）。uart_debug 每 ~9 拍才推进一次状态，而 115200 baud 下每个字节约需 **4,340 个时钟周期**，轮询间隔远小于字节到达间隔，接收完全不受影响。

---

## 五、验证

修复后：

- 行为级仿真：24/24 基本指令全部 PASS（`test_basic_example.py`）
- 上板：通过 UART 下载不同程序均可正确执行（待上板复测）

---

## 六、影响文件

| 文件 | 改动 |
|------|------|
| `rtl/debug/uart_debug.v` | 新增 `stall_i` 端口；13 个 always 块加 `!stall_i` 条件 |
| `rtl/soc/tinyriscv_soc_top.v` | uart_debug 例化添加 `.stall_i(mem_bridge_stall)` |