echo off

if "%1"=="" (
    set src=./
) else (
    set src=%1
)

call source/hVHDL_fixed_point/ghdl_compile_math_library.bat source/hVHDL_fixed_point
call source/hVHDL_floating_point/ghdl_compile_vhdl_float.bat source/hVHDL_floating_point/

ghdl -a --ieee=synopsys --std=08 %src%/processor_configuration/ram_configuration_for_simple_processor_pkg.vhd
call source/hVHDL_memory_library/ghdl_compile_memory_library.bat source/hVHDL_memory_library/

ghdl -a --ieee=synopsys --std=08 %src%/processor_configuration/processor_configuration_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/vhdl_assembler/microinstruction_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/processor_configuration/fixed_point_command_pipeline_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/simple_processor/simple_processor_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/simple_processor/test_programs_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/vhdl_assembler/float_assembler_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/processor_configuration/float_pipeline_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %src%/simple_processor/float_example_program_pkg.vhd
