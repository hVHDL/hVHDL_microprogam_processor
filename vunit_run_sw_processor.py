#!/usr/bin/env python3

from pathlib import Path
from vunit import VUnit

# ROOT
ROOT = Path(__file__).resolve().parent
VU = VUnit.from_argv()

testi = VU.add_library("testi")
testi.add_source_files(ROOT / "testbenches/" "*.vhd")

VU.main()
