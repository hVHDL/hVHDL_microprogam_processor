echo off

if "%1"=="" (
    set microprogram_src=./
) else (
    set microprogram_src=%1
)

call %microprogram_src%/source/hVHDL_fixed_point/ghdl_compile_math_library.bat %microprogram_src%/source/hVHDL_fixed_point
call %microprogram_src%/source/hVHDL_floating_point/ghdl_compile_vhdl_float.bat %microprogram_src%/source/hVHDL_floating_point/

ghdl -a --ieee=synopsys --std=08 %microprogram_src%/processor_configuration/ram_configuration_for_simple_processor_pkg.vhd
call %microprogram_src%/source/hVHDL_memory_library/ghdl_compile_memory_library.bat %microprogram_src%/source/hVHDL_memory_library/

ghdl -a --ieee=synopsys --std=08 %microprogram_src%/processor_configuration/processor_configuration_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/vhdl_assembler/microinstruction_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/processor_configuration/fixed_point_command_pipeline_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/simple_processor/simple_processor_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/simple_processor/test_programs_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/vhdl_assembler/float_assembler_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/processor_configuration/float_pipeline_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/simple_processor/float_example_program_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/memory_processor/memory_processing_pkg.vhd
ghdl -a --ieee=synopsys --std=08 %microprogram_src%/memory_processor/memory_processor.vhd
