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

v2008 = VU.add_library("v2008")

v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/real_to_fixed/real_to_fixed_pkg.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_memory_library/vhdl2008/dp_ram_w_configurable_recrods.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_memory_library/vhdl2008/arch_sim_dp_ram_w_configurable_records.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_memory_library/vhdl2008/mpram_w_configurable_records.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_floating_point/vhdl2008/*.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_floating_point/vhdl2008/altera/multiply_add_arch_agilex.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_floating_point/vhdl2008/altera/sim_native_fp32.vhd")

v2008.add_source_files(ROOT / "rtl/ram_connector_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/execution_unit.vhd")
v2008.add_source_files(ROOT / "rtl/microprogram_sequencer.vhd")
v2008.add_source_files(ROOT / "rtl/generic_microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/microprogram_assembler_pkg.vhd")
v2008.add_source_files(ROOT / "examples/boost_converter_pkg.vhd")

v2008.add_source_files(ROOT / "rtl/microprogram_interface_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/microprogram_core.vhd")

v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_dsp/fixed_dsp.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_dsp/arch_rtl_fixed_dsp.vhd")
v2008.add_source_files(ROOT / "rtl/arch_float_mult_add.vhd")
v2008.add_source_files(ROOT / "rtl/arch_fixed_mult_add.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/lut_interpolation/lut_reciprocal_pkg.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/reciprocal_calculator/reciprocal_calculator.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_point_scaling/fixed_point_scaling_pkg.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/lut_divider/lut_divider.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/lut_interpolation/lut_sqrt_pkg.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/sqrt_calculator/sqrt_calculator.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/full_range_sqrt/full_range_sqrt.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/lut_interpolation/lut_sine_pkg.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/sine_calculator/sine_calculator.vhd")
v2008.add_source_files(ROOT / "rtl/arch_fixed_math.vhd")

v2008.add_source_files(ROOT / "testbenches/microprogram_sequencer_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/float_microprogram_core_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/fixed_execution_unit_tb.vhd")

fixed_tb = v2008.test_bench("fixed_execution_unit_tb")
architecture = "fixed_mult_add"
for pre_add_register in [False, True]:
    fixed_tb.add_config(
        name=architecture + ("_pre_add_register" if pre_add_register else ""),
        generics=dict(g_pre_add_register=pre_add_register))
fixed_tb.add_config(
    name=architecture + "_pre_add_and_product_registers",
    generics=dict(g_pre_add_register=True, g_product_register=True))
# 36 bit data and instructions
fixed_tb.add_config(
    name=architecture + "_36_bit",
    generics=dict(g_data_width=36, g_instruction_width=36))
fixed_tb.add_config(
    name=architecture + "_36_bit_pre_add_and_product_registers",
    generics=dict(g_data_width=36, g_instruction_width=36,
                  g_pre_add_register=True, g_product_register=True))
# no ram output registers
fixed_tb.add_config(
    name=architecture + "_no_ram_output_registers",
    generics=dict(g_program_ram_output_register=False, g_data_ram_output_register=False))
fixed_tb.add_config(
    name=architecture + "_36_bit_no_ram_output_registers",
    generics=dict(g_data_width=36, g_instruction_width=36,
                  g_program_ram_output_register=False, g_data_ram_output_register=False))
# a 128 word program ram
fixed_tb.add_config(
    name=architecture + "_128_word_program",
    generics=dict(g_program_address_width=7))

v2008.add_source_files(ROOT / "testbenches/result_latency_tb.vhd")
latency_tb = v2008.test_bench("result_latency_tb")
architecture = "fixed_mult_add"
for pre_add_register in [False, True]:
    for product_register in [False, True]:
        for data_ram_output_register in [True, False]:
            latency_tb.add_config(
                name=architecture + ("_pre_add" if pre_add_register else "") + ("_product" if product_register else "")
                    + ("" if data_ram_output_register else "_no_data_ram_register"),
                generics=dict(g_pre_add_register=pre_add_register, g_product_register=product_register,
                              g_data_ram_output_register=data_ram_output_register))

v2008.add_source_files(ROOT / "testbenches/portable_program_tb.vhd")
portable_tb = v2008.test_bench("portable_program_tb")
architecture = "fixed_mult_add"
for registers in [False, True]:
    for width in [32, 36]:
        for program_ram_register, data_ram_register in [(True, True), (False, True), (True, False), (False, False)]:
            portable_tb.add_config(
                name=f"{architecture}{'_pre_add_and_product' if registers else ''}_{width}_bit"
                    + ("" if program_ram_register else "_no_program_ram_register")
                    + ("" if data_ram_register else "_no_data_ram_register"),
                generics=dict(g_pre_add_register=registers, g_product_register=registers,
                              g_data_width=width, g_instruction_width=width,
                              g_program_ram_output_register=program_ram_register,
                              g_data_ram_output_register=data_ram_register))

for registers in [False, True]:
    for program_ram_register in [True, False]:
        portable_tb.add_config(
            name=f"{architecture}{'_pre_add_and_product' if registers else ''}_program_cache"
                + ("" if program_ram_register else "_no_program_ram_register"),
            generics=dict(g_pre_add_register=registers, g_product_register=registers,
                          g_program_ram_output_register=program_ram_register, g_program_cache=True))

v2008.add_source_files(ROOT / "testbenches/math_unit_tb.vhd")
math_tb = v2008.test_bench("math_unit_tb")
for width in [32, 36]:
    for registers in [False, True]:
        for data_ram_register in [True, False]:
            math_tb.add_config(
                name=f"{width}_bit{'_pre_add_and_product' if registers else ''}{'' if data_ram_register else '_no_data_ram_register'}",
                generics=dict(g_data_width=width, g_pre_add_register=registers, g_product_register=registers,
                              g_data_ram_output_register=data_ram_register))
for width in [32, 36]:
    math_tb.add_config(name=f"{width}_bit_3_divider_shifter_stages",
        generics=dict(g_data_width=width, g_divider_shifter_stages=3))
    math_tb.add_config(name=f"{width}_bit_no_math_registers",
        generics=dict(g_data_width=width, g_math_ram_output_register=False, g_math_dsp_request_register=False))
    math_tb.add_config(name=f"{width}_bit_no_math_ram_register_pre_add",
        generics=dict(g_data_width=width, g_math_ram_output_register=False, g_pre_add_register=True))
    math_tb.add_config(name=f"{width}_bit_no_math_request_register_4_shifter_stages",
        generics=dict(g_data_width=width, g_math_dsp_request_register=False, g_divider_shifter_stages=4))

if args.dump_arrays:
    VU.set_sim_option("nvc.sim_flags", ["-w", "--dump-arrays"])

VU.main()
