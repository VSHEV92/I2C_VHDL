create_project I2C_Tests_project ../I2C_Tests_project -part xc7a50tftg256-1

add_files -fileset sim_1 -norecurse ../source/I2C_EEPROM.vhd
add_files -fileset sim_1 -norecurse ../source/I2C_Master_Beh.vhd

add_files -fileset sim_1 -norecurse ../tests/PAGE_WR_SEQ_RAND_RD_Beh.vhd
add_files -fileset sim_1 -norecurse ../tests/BYTE_WR_RAND_RD_and_SEQ_RD_Beh.vhd
add_files -fileset sim_1 -norecurse ../tests/PAGE_WR_WC_High_Beh.vhd

