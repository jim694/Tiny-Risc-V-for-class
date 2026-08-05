# 时钟约束50MHz
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {clk}]; 
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports {clk}];



# 时钟引脚

# 测试时钟引脚
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN Y18 [get_ports clk]

# 复位引脚
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PACKAGE_PIN F20 [get_ports rst]

# 注：F19是LED1
# 程序执行成功指示引脚
set_property IOSTANDARD LVCMOS33 [get_ports succ]
set_property PACKAGE_PIN F19 [get_ports succ]

# over，已恢复接空引脚
set_property IOSTANDARD LVCMOS33 [get_ports over]
set_property PACKAGE_PIN F14 [get_ports over]
# set_property PACKAGE_PIN C20 [get_ports over]

# 串口发送引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_tx_pin]
set_property PACKAGE_PIN G16 [get_ports uart_tx_pin]

# 串口接收引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_rx_pin]
set_property PACKAGE_PIN G15 [get_ports uart_rx_pin]

# PWM 引脚
# LED2-PWM0
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[0]]
set_property PACKAGE_PIN E21 [get_ports pwm_o[0]]

# LED3-PWM1
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[1]]
set_property PACKAGE_PIN D20 [get_ports pwm_o[1]]

# LED4-PWM2，已恢复
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[2]]
set_property PACKAGE_PIN C20 [get_ports pwm_o[2]]
# set_property PACKAGE_PIN F14 [get_ports pwm_o[2]]

# 空端口-PWM3
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[3]]
set_property PACKAGE_PIN E14 [get_ports pwm_o[3]]






# I2C 引脚（接温度传感器）
set_property IOSTANDARD LVCMOS33 [get_ports io_scl]
set_property PACKAGE_PIN M22 [get_ports io_scl]
set_property PULLUP true [get_ports io_scl]

set_property IOSTANDARD LVCMOS33 [get_ports io_sda]
set_property PACKAGE_PIN N22 [get_ports io_sda]
set_property PULLUP true [get_ports io_sda]

# Debug 引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_debug_pin]
set_property PACKAGE_PIN M13 [get_ports uart_debug_pin]
