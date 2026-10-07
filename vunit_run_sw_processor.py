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

v2008.add_source_files(ROOT / "vhdl2008/ram_connector_pkg.vhd")
v2008.add_source_files(ROOT / "vhdl2008/instruction_pkg.vhd")
v2008.add_source_files(ROOT / "vhdl2008/addsub.vhd")
v2008.add_source_files(ROOT / "vhdl2008/microprogram_sequencer.vhd")
v2008.add_source_files(ROOT / "vhdl2008/vhdl2008_microinstruction_pkg.vhd")
v2008.add_source_files(ROOT / "vhdl2008/def_microinstruction_pkg.vhd")

v2008.add_source_files(ROOT / "vhdl2008/microprogram_processor_pkg.vhd")
v2008.add_source_files(ROOT / "vhdl2008/microprogram_processor.vhd")
v2008.add_source_files(ROOT / "vhdl2008/microprogram_controller.vhd")

v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_dsp/fixed_dsp.vhd")
v2008.add_source_files(ROOT / "source/hVHDL_fixed_point/fixed_dsp/arch_rtl_fixed_dsp.vhd")
v2008.add_source_files(ROOT / "vhdl2008/arch_float_mult_add.vhd")
v2008.add_source_files(ROOT / "vhdl2008/arch_fixed_mult_add.vhd")

v2008.add_source_files(ROOT / "testbenches/vhdl2008/microprogram_sequencer_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/vhdl2008/retry_microprogram_processor_tb.vhd")
v2008.add_source_files(ROOT / "testbenches/vhdl2008/float_microprocessor_tb.vhd")

if args.dump_arrays:
    VU.set_sim_option("nvc.sim_flags", ["-w", "--dump-arrays"])

VU.main()
