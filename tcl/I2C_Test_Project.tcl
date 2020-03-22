create_project I2C_Tests_project ../I2C_Tests_project -part xc7a50tftg256-1

add_files -fileset sim_1 -norecurse ../source/I2C_EEPROM.vhd
add_files -fileset sim_1 -norecurse ../source/I2C_Master_Beh.vhd
add_files -fileset sim_1 -norecurse ../source/Data_Generator.vhd
add_files -fileset sim_1 -norecurse ../source/I2C_EEPROM_Controller.vhd
add_files -fileset sim_1 -norecurse ../source/Start_Edge_Detector.vhd

add_files -fileset sim_1 -norecurse ../tests/PAGE_WR_SEQ_RAND_RD_Beh.vhd
add_files -fileset sim_1 -norecurse ../tests/BYTE_WR_RAND_RD_and_SEQ_RD_Beh.vhd
add_files -fileset sim_1 -norecurse ../tests/PAGE_WR_WC_High_Beh.vhd

add_files -fileset sim_1 -norecurse ../tests/PAGE_WR_SEQ_RAND_RD.vhd
add_files -fileset sim_1 -norecurse ../tests/BYTE_WR_RAND_RD_and_SEQ_RD.vhd
add_files -fileset sim_1 -norecurse ../tests/PAGE_WR_WC_High.vhd

create_ip -name fifo_generator -vendor xilinx.com -library ip -version 13.2 -module_name IFIFO
set_property -dict [list CONFIG.Component_Name {IFIFO} CONFIG.Input_Data_Width {8} CONFIG.Input_Depth {256} CONFIG.Output_Data_Width {16} CONFIG.Output_Depth {128} CONFIG.Use_Extra_Logic {true} CONFIG.Data_Count_Width {8} CONFIG.Write_Data_Count_Width {9} CONFIG.Read_Data_Count_Width {8} CONFIG.Full_Threshold_Assert_Value {253} CONFIG.Full_Threshold_Negate_Value {252}] [get_ips IFIFO]
generate_target {instantiation_template} [get_files /home/vovan/VivadoProjects/I2C_EEPROM/I2C_Tests_project/I2C_Tests_project.srcs/sources_1/ip/IFIFO/IFIFO.xci]
update_compile_order -fileset sources_1

