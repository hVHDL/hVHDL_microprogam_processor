# hVHDL microprogram processor

A small VHDL-2008 processor that runs microprograms written in VHDL: a
sequencer steps through a program RAM and pushes each instruction into an
instruction pipeline, and an `instruction` entity reads its operands from a
data RAM, does the arithmetic and writes the result back. The arithmetic is
an architecture of `instruction`, so the same sequencer runs fixed point or
floating point programs.

```
source/                          submodules: hVHDL_fixed_point,
                                 hVHDL_floating_point, hVHDL_memory_library
vhdl2008/
  vhdl2008_microinstruction_pkg.vhd   generic_microinstruction_pkg: commands,
                                      instruction format, op() assembler
  def_microinstruction_pkg.vhd        microinstruction_pkg, its default instance
                                      (32 bit instructions and data)
  microprogram_processor_pkg.vhd      start / ready interface: calculate(),
                                      is_ready()
  microprogram_sequencer.vhd          program counter, set_rpt / jump loops,
                                      instruction pipeline
  instruction_pkg.vhd                 entity instruction and its port records
  addsub.vhd                          architecture add_sub_mpy (fixed point)
  arch_fixed_mult_add.vhd             architecture fixed_mult_add (a * b + c)
  arch_float_mult_add.vhd             architecture float_mult_add (hfloat)
  microprogram_processor.vhd          sequencer + program and data RAMs +
                                      add_sub_mpy in one entity
  microprogram_controller.vhd         sequencer + RAMs, the instruction
                                      entity connected from outside
  ram_connector_pkg.vhd               helpers for combining RAM ports
testbenches/vhdl2008/            sequencer, processor and float controller
vunit_run_sw_processor.py        VUnit run script
```

## Instructions

An instruction is 32 bits: a 4 bit command, a 7 bit destination and three
7 bit argument addresses into the data RAM, or for `set_rpt` and `jump` a
single argument, the repeat count or the jump address, of which the
sequencer reads the low 21 bits. Programs and data are RAM initial values, written with
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
`neg_mpy_sub` change the signs of the product and c (in `fixed_mult_add`
with a bitwise `not`, −x − 1, and the result is bits radix + 31 … radix of
a·b + c·2^radix). `a_add_b_mpy_c`,
`a_sub_b_mpy_c`, `lp_filter` and the accumulator commands are in the fixed
point architectures. There is no hazard detection: a result is in the data
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

The testbenches run the processors but do not check their results yet.
