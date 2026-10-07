# hVHDL microprogram processor

A small VHDL-2008 processor that runs microprograms written in VHDL: a
sequencer steps through a program RAM and pushes each instruction into an
instruction pipeline, and an execution unit reads its operands from a data
RAM, does the arithmetic and writes the result back. The arithmetic is an
architecture of `execution_unit`, so the same sequencer runs fixed point or
floating point programs.

```
source/                          submodules: hVHDL_fixed_point,
                                 hVHDL_floating_point, hVHDL_memory_library
rtl/
  generic_microinstruction_pkg.vhd    commands, instruction format and the
                                      op() assembler
  microinstruction_pkg.vhd            its default instance (32 bit
                                      instructions and data)
  microprogram_interface_pkg.vhd      start / ready records: calculate(),
                                      is_ready()
  microprogram_sequencer.vhd          program counter, set_rpt / jump loops,
                                      instruction pipeline
  execution_unit.vhd                  entity execution_unit and its port
                                      records
  arch_fixed_mult_add.vhd             fixed_mult_add : fixed_dsp, data width
                                      accumulator
  arch_fixed_mult_acc.vhd             fixed_mult_acc : fixed_dsp, double
                                      width product accumulator
  arch_float_mult_add.vhd             float_mult_add : hfloat
  microprogram_core.vhd               sequencer + program and data RAMs, the
                                      execution unit connected from outside
                                      (to_unit / from_unit)
  fixed_microprogram_processor.vhd    sequencer + RAMs + fixed_mult_acc in one
                                      entity
  ram_connector_pkg.vhd               helpers for combining RAM ports
testbenches/                     fixed_execution_unit_tb checks both fixed
                                 point architectures, the others run the
                                 sequencer, fixed_microprogram_processor and
                                 the float core
vunit_run_sw_processor.py        VUnit run script
```

## Instructions

An instruction is 32 bits: a 4 bit command, a 7 bit destination and three
7 bit argument addresses into the data RAM, or for `set_rpt` and `jump` a
single argument, the repeat count or the jump address, of which the
sequencer reads the low 21 bits. The fields are in bits 31..0; a program
RAM can be wider (`resize_instruction()` zero extends an `op()`), and the
pipeline, `decode()` and the field functions take its width. The program
and data RAMs' sizes and word widths come from their initial contents,
`g_program` and `g_data` (a power of 2 words each); the data width sets
the execution unit's. Programs and data are RAM initial values, written with
`op()`:

```vhdl
constant program : work.dual_port_ram_pkg.ram_array(0 to 1023)(31 downto 0) := (
      128 => op(set_rpt     , 1500)
    , 129 => op(neg_mpy_add , inductor_voltage , duty , cap_voltage      , input_voltage)
    , 130 => op(mpy_sub     , cap_current      , duty , inductor_current , load)
    ...
    , 158 => op(program_end)
    , others => op(nop));
```

`mpy_add dest, a, b, c` is dest = a·b + c, and `mpy_sub`, `neg_mpy_add`,
`neg_mpy_sub` change the signs of the product and c. `fixed_mult_add` runs
on hVHDL_fixed_point's `fixed_dsp`: sums, differences and −a wrap to the
data width in its pre-adder, and the result is bits radix + width − 1 …
radix of a·b ± c·2^radix; `g_pre_add_register` registers the pre-adder
and `g_product_register` the product before the result adder, each one
clock more to the result. `a_add_b_mpy_c`,
`a_sub_b_mpy_c`, `lp_filter` and the accumulator commands are in the fixed
point architectures. `fixed_mult_acc` runs the same multiply-adds on its
`fixed_dsp`, and its accumulator is at the product's width: `mpy_acc` adds
a·b, `acc` adds c, `get_acc_and_zero` writes the accumulator + c and zeroes
it. In `fixed_mult_add` the accumulator is data width, `acc` and
`get_acc_and_zero` add c, and there is no `mpy_acc`. There is no hazard detection: a result is in the data
RAM only after the pipeline delay, so a program spaces dependent
instructions with addresses left as `nop`. A `jump` takes effect after the
three instructions that follow it, which are already fetched and run on
every round; a `program_end` among them ends the program.

`calculate(mproc_in, start_address)` starts the program at `start_address`;
it runs until `program_end` and `is_ready(mproc_out)` is true for one clock.

## Simulate

```
git submodule update --init --recursive
python3 vunit_run_sw_processor.py
```

`fixed_execution_unit_tb` runs the multiply-add and accumulator commands and
a `jump` loop on both fixed point architectures, with and without the
pre-adder and product registers, with 32 and 36 bit data and instructions
and a 128 word program RAM, and checks every result against a model. The other
testbenches run the processors without checking their results.
