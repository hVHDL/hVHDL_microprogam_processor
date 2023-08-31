#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv()

testi = VU.add_library("testi")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/configuration/multiply_with_1_input_and_output_registers_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_base_types_20bit_pkg.vhd")
testi.add_source_files(ROOT / "source/hVHDL_fixed_point/multiplier/multiplier_pkg.vhd")
testi.add_source_files(ROOT / "testbenches/" "*.vhd")

VU.main()
