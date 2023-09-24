echo off

rem call source/hVHDL_memory_library/ghdl_compile_memory_library.bat source/hVHDL_memory_library
call source/hVHDL_fixed_point/ghdl_compile_math_library.bat source/hVHDL_fixed_point

ghdl -a --ieee=synopsys --std=08 testbenches/microinstruction_pkg.vhd
ghdl -a --ieee=synopsys --std=08 testbenches/test_programs_pkg.vhd
ghdl -a --ieee=synopsys --std=08 ram/ram_configuration_pkg.vhd
ghdl -a --ieee=synopsys --std=08 ram/ram_read_base_pkg.vhd

ghdl -a --ieee=synopsys --std=08 ram/dual_port_ram.vhd

ghdl -a --ieee=synopsys --std=08 testbenches/microcode_processor_pkg.vhd
