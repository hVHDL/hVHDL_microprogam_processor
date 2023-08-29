echo off

rem call source/hVHDL_memory_library/ghdl_compile_memory_library.bat source/hVHDL_memory_library

ghdl -a --ieee=synopsys --std=08 testbenches/testprogram_pkg.vhd
ghdl -a --ieee=synopsys --std=08 testbenches/test_programs_pkg.vhd
ghdl -a --ieee=synopsys --std=08 testbenches/ram_read_base_pkg.vhd
