#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv()

testi = VU.add_library("testi")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_type_definitions/float_word_length_20_bit_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_type_definitions/float_type_definitions_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_arithmetic_operations/*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/normalizer/normalizer_configuration/normalizer_with_4_stage_pipe_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/normalizer/*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/denormalizer/denormalizer_configuration/denormalizer_with_4_stage_pipe_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/denormalizer/*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_to_real_conversions" / "*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_adder/*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_multiplier/*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_alu/*.vhd")
testi.add_source_files(ROOT / "source/hVHDL_floating_point/float_first_order_filter/*.vhd")

testi.add_source_files(ROOT / "source/hVHDL_fixed_point/real_to_fixed/real_to_fixed_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/configuration/multiply_with_1_input_and_output_registers_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_pkg.vhd")

testi.add_source_files(ROOT / "ram/ram_configuration_pkg.vhd")
testi.add_source_files(ROOT / "ram/ram_read_base_pkg.vhd")

testi.add_source_files(ROOT / "ram/dual_port_ram.vhd")

testi.add_source_files(ROOT / "testbenches/" "microinstruction_pkg.vhd")
testi.add_source_files(ROOT / "testbenches/" "microcode_processor_pkg.vhd")
testi.add_source_files(ROOT / "testbenches/" "test_programs_pkg.vhd")

# testi.add_source_files(ROOT / "testbenches/" "processor_w_ram_tb.vhd")
testi.add_source_files(ROOT / "testbenches/ram_read_tb.vhd")
testi.add_source_files(ROOT / "testbenches/processor_w_ram_v2_tb.vhd")
testi.add_source_files(ROOT / "testbenches/tb_pipelined_operations.vhd")
testi.add_source_files(ROOT / "testbenches/tb_swap_registers.vhd")
testi.add_source_files(ROOT / "testbenches/tb_branching.vhd")


testi.add_source_files(ROOT / "testbenches/dual_port_ram/tb_dual_port_ram.vhd")

VU.main()
