echo off

call source/hVHDL_memory_library/ghdl_compile_memory_library.bat source/hVHDL_memory_library

ghdl -a --ieee=synopsys --std=08 testbenches/testprogram_pkg.vhd
