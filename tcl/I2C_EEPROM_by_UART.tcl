create_project I2C_EEPROM_by_UART ../I2C_EEPROM_by_UART -part xc7a50tftg256-1

add_files ../source/I2C_EEPROM_Controller.vhd
add_files ../source/Start_Edge_Detector.vhd

add_files ../source/UART_RX.vhd
add_files ../source/UART_TX.vhd
add_files ../source/I2C_EEPROM_by_UART_Top.vhd


update_compile_order -fileset sources_1

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name OFIFO
set_property -dict [list CONFIG.Component_Name {OFIFO} CONFIG.Input_Data_Width {8} CONFIG.Input_Depth {16} CONFIG.Output_Data_Width {8} CONFIG.Output_Depth {16} CONFIG.Use_Embedded_Registers {false} CONFIG.Reset_Pin {true} CONFIG.Reset_Type {Synchronous_Reset} CONFIG.Use_Dout_Reset {true} CONFIG.Data_Count_Width {4} CONFIG.Write_Data_Count_Width {4} CONFIG.Read_Data_Count_Width {4} CONFIG.Full_Threshold_Assert_Value {14} CONFIG.Full_Threshold_Negate_Value {13}] [get_ips OFIFO]

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name IFIFO
set_property -dict [list CONFIG.Component_Name {IFIFO} CONFIG.Input_Data_Width {8} CONFIG.Input_Depth {256} CONFIG.Output_Data_Width {16} CONFIG.Output_Depth {128} CONFIG.Use_Extra_Logic {true} CONFIG.Data_Count_Width {8} CONFIG.Write_Data_Count_Width {9} CONFIG.Read_Data_Count_Width {8} CONFIG.Full_Threshold_Assert_Value {253} CONFIG.Full_Threshold_Negate_Value {252}] [get_ips IFIFO]
generate_target {instantiation_template} [get_files /home/vovan/VivadoProjects/I2C_EEPROM/I2C_Tests_project/I2C_Tests_project.srcs/sources_1/ip/IFIFO/IFIFO.xci]
update_compile_order -fileset sources_1


add_files -fileset constrs_1 ../constraints/I2C_EEPROM_by_UART_LOC.xdc
add_files -fileset constrs_1 ../constraints/I2C_EEPROM_by_UART_Timing.xdc
