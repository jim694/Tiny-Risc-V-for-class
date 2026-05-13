# 时钟约束50MHz
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {clk}]; 
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports {clk}];

set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {jtag_TCK}]; 
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports {jtag_TCK}];

set_clock_groups -asynchronous -group [get_clocks sys_clk_pin] \
                               -group [get_clocks jtag_TCK]

# 时钟引脚
set_property IOSTANDARD LVCMOS33 [get_ports jtag_TCK]
set_property PACKAGE_PIN A18 [get_ports jtag_TCK]
set_property PULLUP true     [get_ports jtag_TCK]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_ports jtag_TCK]
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets jtag_TCK_IBUF]

# 测试时钟引脚
set_property IOSTANDARD LVCMOS33 [get_ports clk]
set_property PACKAGE_PIN Y18 [get_ports clk]

# 复位引脚
set_property IOSTANDARD LVCMOS33 [get_ports rst]
set_property PACKAGE_PIN F20 [get_ports rst]

# 程序执行成功指示引脚
set_property IOSTANDARD LVCMOS33 [get_ports succ]
set_property PACKAGE_PIN F19 [get_ports succ]

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

# LED4-PWM2
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[2]]
set_property PACKAGE_PIN C20 [get_ports pwm_o[2]]

# LED1-PWM3，助教神了
set_property IOSTANDARD LVCMOS33 [get_ports pwm_o[3]]
set_property PACKAGE_PIN E14 [get_ports pwm_o[3]]

# over，先随便分配一个空端口，后续看能不能挪到LED或bcd7
set_property IOSTANDARD LVCMOS33 [get_ports over]
set_property PACKAGE_PIN F14 [get_ports over]

# JTAG，先分空端口
set_property IOSTANDARD LVCMOS33 [get_ports halted_ind]
set_property PACKAGE_PIN D15 [get_ports halted_ind]

set_property IOSTANDARD LVCMOS33 [get_ports jtag_TMS]
set_property PACKAGE_PIN D14 [get_ports jtag_TMS]

set_property IOSTANDARD LVCMOS33 [get_ports jtag_TDI]
set_property PACKAGE_PIN B13 [get_ports jtag_TDI]

set_property IOSTANDARD LVCMOS33 [get_ports jtag_TDO]
set_property PACKAGE_PIN C13 [get_ports jtag_TDO]


# I2C 引脚，后续接入温度传感器，需要保留
# set_property IOSTANDARD LVCMOS33 [get_ports io_scl]
# set_property PACKAGE_PIN M22 [get_ports io_scl]

# set_property IOSTANDARD LVCMOS33 [get_ports io_sda]
# set_property PACKAGE_PIN N22 [get_ports io_sda]

# Debug 引脚
set_property IOSTANDARD LVCMOS33 [get_ports uart_debug_pin]
set_property PACKAGE_PIN M13 [get_ports uart_debug_pin]