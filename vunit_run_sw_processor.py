#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit
import argparse

# Parse extra arguments
parser = argparse.ArgumentParser()
parser.add_argument(
    "--dump-arrays",
    action="store_true",
    help="Enable dumping arrays in the NVC simulator"
)
args, vunit_args = parser.parse_known_args()

ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv(vunit_args)

fixed_point = VU.add_library("fixed_point")

fixed_point.add_source_files(ROOT / "source/hVHDL_fixed_point/real_to_fixed/real_to_fixed_pkg.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/configuration/multiply_with_1_input_and_output_registers_pkg.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_pkg.vhd")

fixed_point.add_source_files(ROOT / "processor_configuration/ram_configuration_for_simple_processor_pkg.vhd")

fixed_point.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/multi_port_ram_pkg.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/ram_read_x2_write_x1.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/arch_sim_read_x2_write_x1.vhd")

fixed_point.add_source_files(ROOT / "source/hVHDL_floating_point/normalizer/normalizer_configuration/normalizer_with_3_stage_pipe_pkg.vhd")
fixed_point.add_source_files(ROOT / "source/hVHDL_floating_point/denormalizer/denormalizer_configuration/denormalizer_with_4_stage_pipe_pkg.vhd")
fixed_point.add_source_files(ROOT / "processor_configuration/processor_configuration_pkg.vhd")
fixed_point.add_source_files(ROOT / "vhdl_assembler/microinstruction_pkg.vhd")
fixed_point.add_source_files(ROOT / "simple_processor/test_programs_pkg.vhd")
fixed_point.add_source_files(ROOT / "processor_configuration/fixed_point_command_pipeline_pkg.vhd")
fixed_point.add_source_files(ROOT / "simple_processor/simple_processor_pkg.vhd")

# fixed_point.add_source_files(ROOT / "testbenches/low_pass_filter_tb.vhd")
#---------------------------------------------------------
float = VU.add_library("float")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_type_definitions/float_word_length_24_bit_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_type_definitions/float_type_definitions_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_arithmetic_operations/float_arithmetic_operations_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/normalizer/normalizer_configuration/normalizer_with_1_stage_pipe_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/denormalizer/denormalizer_configuration/denormalizer_with_1_stage_pipe_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/normalizer/*.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/denormalizer/denormalizer_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_to_real_conversions" / "*.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_adder/*.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_multiplier/*.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_alu/*.vhd")
float.add_source_files(ROOT / "source/hVHDL_floating_point/float_first_order_filter/*.vhd")

float.add_source_files(ROOT / "source/hVHDL_fixed_point/real_to_fixed/real_to_fixed_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/configuration/multiply_with_1_input_and_output_registers_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_pkg.vhd")

float.add_source_files(ROOT / "processor_configuration/float_processor_ram_width_pkg.vhd")

float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/multi_port_ram_pkg.vhd")
float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/multi_port_ram_entity.vhd")
float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/arch_sim_multi_port_ram.vhd")

float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/ram_read_x2_write_x1.vhd")
float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/arch_sim_read_x2_write_x1.vhd")

float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/ram_read_x4_write_x1.vhd")
float.add_source_files(ROOT / "source/hVHDL_memory_library/multi_port_ram/arch_sim_read_x4_write_x1.vhd")

float.add_source_files(ROOT / "processor_configuration/processor_configuration_pkg.vhd")
float.add_source_files(ROOT / "vhdl_assembler/microinstruction_pkg.vhd")
float.add_source_files(ROOT / "vhdl_assembler/float_assembler_pkg.vhd")
float.add_source_files(ROOT / "simple_processor/test_programs_pkg.vhd")
float.add_source_files(ROOT / "processor_configuration/float_pipeline_pkg.vhd")
float.add_source_files(ROOT / "simple_processor/simple_processor_pkg.vhd")
float.add_source_files(ROOT / "memory_processor/memory_processing_pkg.vhd")
float.add_source_files(ROOT / "memory_processor/memory_processor.vhd")

float.add_source_files(ROOT / "simple_processor/float_example_program_pkg.vhd")

# float.add_source_files(ROOT / "testbenches/float_processor_tb.vhd")
# float.add_source_files(ROOT / "testbenches/memory_processor/memory_processor_pipeline_tb.vhd")
# float.add_source_files(ROOT / "testbenches/memory_processor/memory_processor_tb.vhd")
# float.add_source_files(ROOT / "testbenches/memory_processor/lcr_simulation_tb.vhd")

# float.add_source_files(ROOT / "testbenches/memory_processor/lcr_3ph_tb.vhd")
# float.add_source_files(ROOT / "testbenches/memory_processor/lcr_simulation_rk4_tb.vhd")

v2008 = VU.add_library("v2008")

v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/real_to_fixed/real_to_fixed_pkg.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_memory_library/vhdl2008/dp_ram_w_configurable_recrods.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_memory_library/vhdl2008/arch_sim_dp_ram_w_configurable_records.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_memory_library/vhdl2008/mpram_w_configurable_records.vhd")
v2008.add_source_files(ROOT / "vhdl2008/vhdl2008_microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / "vhdl2008/ram_connector_pkg.vhd")


v2008.add_source_files(ROOT / "source/hVHDL_floating_point/vhdl2008/*.vhd")


v2008.add_source_files(ROOT / "vhdl2008/addsub.vhd")
v2008.add_source_files(ROOT / "vhdl2008/microprogram_sequencer.vhd")
v2008.add_source_files(ROOT / "vhdl2008/microprogram_processor.vhd")
v2008.add_source_files(ROOT / "vhdl2008/microprogram_controller.vhd")

v2008.add_source_files(ROOT / "testbenches/vhdl2008/microprogram_sequencer_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/vhdl2008/retry_microprogram_processor_tb.vhd")

v2008.add_source_files(ROOT / "vhdl2008/arch_float_mult_add.vhd")
v2008.add_source_files(ROOT / "vhdl2008/arch_fixed_mult_add.vhd")
v2008.add_source_files(ROOT / "testbenches/vhdl2008/float_microprocessor_tb.vhd")

if args.dump_arrays:
    VU.set_sim_option("nvc.sim_flags", ["-w", "--dump-arrays"])

VU.main()
