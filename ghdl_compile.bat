echo off

ghdl -a --ieee=synopsys --std=08 source/hVHDL_memory_library/fpga_ram/ram_configuration/ram_configuration_16x1024_pkg.vhd
ghdl -a --ieee=synopsys --std=08 source/hVHDL_memory_library/fpga_ram/ram_read_port_pkg.vhd
