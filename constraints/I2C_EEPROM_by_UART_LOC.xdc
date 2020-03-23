# размещение пинов для платы AES-A7EV-7A50T-G

# тактовый сигнал
set_property PACKAGE_PIN N11 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# кнопка сброса (SW1)
set_property PACKAGE_PIN N4 [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]

# кнопка старта транзакции (SW2)
set_property PACKAGE_PIN R2 [get_ports Start_Button]
set_property IOSTANDARD LVCMOS33 [get_ports Start_Button]

# RX сигнал UART
set_property PACKAGE_PIN M12 [get_ports rx]
set_property IOSTANDARD LVCMOS33 [get_ports rx]

# TX сигнал UART
set_property PACKAGE_PIN N6 [get_ports tx]
set_property IOSTANDARD LVCMOS33 [get_ports tx]

# сигнал готовности к следующей транзакции
set_property PACKAGE_PIN L5 [get_ports Done]
set_property IOSTANDARD LVCMOS33 [get_ports Done]

# I2C сигналы для EEPROM
set_property PACKAGE_PIN R6 [get_ports SCL]
set_property IOSTANDARD LVCMOS33 [get_ports SCL]
set_property PACKAGE_PIN R7 [get_ports SDA]
set_property IOSTANDARD LVCMOS33 [get_ports SDA]

