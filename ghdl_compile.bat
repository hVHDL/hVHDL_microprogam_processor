echo off

if "%1"=="" (
    set src=./
) else (
    set src=%1
)

call source/hVHDL_fixed_point/ghdl_compile_math_library.bat source/hVHDL_fixed_point
call source/hVHDL_memory_library/ghdl_compile_memory_library.bat source/hVHDL_memory_library

ghdl -a --ieee=synopsys --std=08 %src%/vhdl_assembler/microinstruction_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/simple_processor/simple_processor_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/simple_processor/test_programs_pkg.vhd
