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
v2008.add_source_files(ROOT / "rtl/arch_fixed_mult_acc.vhd")
v2008.add_source_files(ROOT / "rtl/microprogram_sequencer.vhd")
v2008.add_source_files(ROOT / "rtl/generic_microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/microprogram_assembler_pkg.vhd")

v2008.add_source_files(ROOT / "rtl/microprogram_interface_pkg.vhd")
v2008.add_source_files(ROOT / "rtl/fixed_microprogram_processor.vhd")
v2008.add_source_files(ROOT / "rtl/microprogram_core.vhd")

v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_dsp/fixed_dsp.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_dsp/arch_rtl_fixed_dsp.vhd")
v2008.add_source_files(ROOT / "rtl/arch_float_mult_add.vhd")
v2008.add_source_files(ROOT / "rtl/arch_fixed_mult_add.vhd")

v2008.add_source_files(ROOT / "testbenches/microprogram_sequencer_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/fixed_microprogram_processor_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/float_microprogram_core_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/fixed_execution_unit_tb.vhd")

fixed_tb = v2008.test_bench("fixed_execution_unit_tb")
for architecture in ["fixed_mult_add", "fixed_mult_acc"]:
    for pre_add_register in [False, True]:
        fixed_tb.add_config(
            name=architecture + ("_pre_add_register" if pre_add_register else ""),
            generics=dict(g_architecture=architecture, g_pre_add_register=pre_add_register))
    fixed_tb.add_config(
        name=architecture + "_pre_add_and_product_registers",
        generics=dict(g_architecture=architecture, g_pre_add_register=True, g_product_register=True))
    # 36 bit data and instructions
    fixed_tb.add_config(
        name=architecture + "_36_bit",
        generics=dict(g_architecture=architecture, g_data_width=36, g_instruction_width=36))
    fixed_tb.add_config(
        name=architecture + "_36_bit_pre_add_and_product_registers",
        generics=dict(g_architecture=architecture, g_data_width=36, g_instruction_width=36,
                      g_pre_add_register=True, g_product_register=True))
    # a 128 word program ram
    fixed_tb.add_config(
        name=architecture + "_128_word_program",
        generics=dict(g_architecture=architecture, g_program_address_width=7))

v2008.add_source_files(ROOT / "testbenches/result_latency_tb.vhd")
latency_tb = v2008.test_bench("result_latency_tb")
for architecture in ["fixed_mult_add", "fixed_mult_acc"]:
    for pre_add_register in [False, True]:
        for product_register in [False, True]:
            latency_tb.add_config(
                name=architecture + ("_pre_add" if pre_add_register else "") + ("_product" if product_register else ""),
                generics=dict(g_architecture=architecture, g_pre_add_register=pre_add_register,
                              g_product_register=product_register))

v2008.add_source_files(ROOT / "testbenches/portable_program_tb.vhd")
portable_tb = v2008.test_bench("portable_program_tb")
for architecture in ["fixed_mult_add", "fixed_mult_acc"]:
    for registers in [False, True]:
        for width in [32, 36]:
            portable_tb.add_config(
                name=f"{architecture}{'_pre_add_and_product' if registers else ''}_{width}_bit",
                generics=dict(g_architecture=architecture, g_pre_add_register=registers,
                              g_product_register=registers, g_data_width=width, g_instruction_width=width))

if args.dump_arrays:
    VU.set_sim_option("nvc.sim_flags", ["-w", "--dump-arrays"])

VU.main()
