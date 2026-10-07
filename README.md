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
  microprogram_assembler_pkg.vhd      schedule(), repeat(), place() : one
                                      program source for any configuration
  ram_connector_pkg.vhd               helpers for combining RAM ports
testbenches/                     fixed_execution_unit_tb checks both fixed
                                 point architectures, result_latency_tb
                                 measures their result latency,
                                 portable_program_tb runs one program source
                                 on eight configurations ; the others run the
                                 sequencer, fixed_microprogram_processor and
                                 the float core
vunit_run_sw_processor.py        VUnit run script
```

## Instructions

The instruction format follows the program RAM's word width: a 4 bit
command above four address fields of (width − 4) / 4 bits — the
destination and three arguments, addresses in the data RAM — packed from
bit 0 up, any spare bits on top. `set_rpt` and `jump` take one argument,
the repeat count or the jump address, across the three argument fields.

| width | address fields | data words reached | `set_rpt` / `jump` argument |
|------:|---------------:|-------------------:|----------------------------:|
| 32    | 7 bits         | 128                | 21 bits                     |
| 36    | 8 bits         | 256                | 24 bits                     |
| 40    | 9 bits         | 512                | 27 bits                     |
| 44    | 10 bits        | 1024               | 30 bits                     |

`decode()` and the `get_` functions take the format from the length of
the instruction they are given, so the sequencer and the execution units
need no format setting. `microprogram_core` checks that the address fields
do not reach past its data RAM. The program and data RAMs' sizes and word
widths come from their initial contents, `g_program` and `g_data` (a power
of 2 words each); the data width sets the execution unit's.

Programs are RAM initial values. `mi()` builds an instruction and
`encode()` encodes a program for a width:

```vhdl
function make_program return microprogram is
    variable program : microprogram(0 to 1023) := (others => mi(nop));
begin
    program(128) := mi(set_rpt     , 1500);
    program(129) := mi(neg_mpy_add , inductor_voltage , duty , cap_voltage      , input_voltage);
    program(130) := mi(mpy_sub     , cap_current      , duty , inductor_current , load);
    ...
    program(158) := mi(program_end);
    return program;
end make_program;

constant program : work.dual_port_ram_pkg.ram_array(0 to 1023)(35 downto 0) := encode(make_program, 36);
```

`op()`, with the same arguments, writes a 32 bit instruction directly.

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
`get_acc_and_zero` add c, and there is no `mpy_acc`. There is no hazard detection in the hardware: a result is in the data
RAM only after the pipeline delay, so dependent instructions are spaced
with `nop`s, by hand or by `schedule()` below. A `jump` takes effect after
the three instructions that follow it, which are already fetched and run
on every round; a `program_end` among them ends the program.

## Result latency and the RAM collision

`execution_unit_pkg.fixed_point_result_latency(pre_add_register,
product_register)` is how many instructions after an instruction the first
one that reads its result can be: 7, plus 1 for each of the pre-adder and
product registers, for `fixed_mult_add` and `fixed_mult_acc` alike.
`result_latency_tb` measures it at the data RAM's ports.

It is the result stage + 2: the RAM takes the write a clock after the
execution unit's result stage, and a read must come in a later clock than
the write. The data RAM reads on one port and writes on the other, and a
read of the address being written in the same clock is a port collision,
which none of the FPGAs this is built for resolves to the new data:

| FPGA, tool | mixed-port read during write, as inferred | the read gives |
|---|---|---|
| Agilex 3, Quartus Pro 26.1 | `READ_DURING_WRITE_MODE_MIXED_PORTS = DONT_CARE` | undefined data |
| Artix-7, Vivado 2024.2 | write port `WRITE_FIRST`, read port `READ_FIRST` | invalid data (a 7-series collision with the writing port in `WRITE_FIRST`) |
| Titanium, Trion, Efinity 2026.1 | not reported | not verified, treated as undefined |
| simulation, both RAM models | | the old data |

Even `OLD_DATA` would give the previous value, so a program must never
read a result in its write clock. Write forwarding on the three read ports
would take a clock off the latency, at a comparator and a multiplexer per
port.

## One program for any configuration

`microprogram_assembler_pkg` lays a program out for a `processor_config`
(instruction width, data width, radix, result latency):

```vhdl
constant config : processor_config := (instruction_width => 36, data_width => 36, radix => 24,
    result_latency => fixed_point_result_latency(pre_add_register, product_register));

function boost_step (m : boost_map) return microprogram is
begin
    return (mi(neg_mpy_add , m.vl , m.duty , m.u      , m.vin)
           ,mi(mpy_sub     , m.ic , m.duty , m.i      , m.load)
           ,mi(neg_mpy_add , m.vl , m.r    , m.i      , m.vl)
           ,mi(mpy_add     , m.u  , m.ic   , m.u_gain , m.u)
           ,mi(mpy_add     , m.i  , m.vl   , m.i_gain , m.i));
end boost_step;

program := place(program, 128, repeat(config, 50, boost_step(boost)) & mi(program_end));
```

- `schedule(config, code)` issues each instruction, in order, in the first
  slot where the results it reads are readable, and pads the code's end
  until all its results are, so scheduled code can follow other code with
  `&` and `program_end` after it means the results are in the RAM.
  `get_acc_and_zero` holds back a following accumulator command.
- `repeat(config, count, code)` makes `set_rpt`, the scheduled code and a
  relative `jump`, placed so a round starts when the last round's results
  are readable; code can sit in the jump's delay slots. Repeats do not
  nest, the sequencer has one repeat counter.
- `place(program, at, code)` puts code at an entry address and fails on an
  overlap; `encode()` resolves the relative jumps.

At latency 7 the boost converter step above takes 21 clocks a round and
the low pass filter 7, against 36 and 20 for the same programs spaced by
hand for the slowest configuration.

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
