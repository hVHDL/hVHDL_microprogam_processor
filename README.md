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
  arch_float_mult_add.vhd             float_mult_add : hfloat
  microprogram_core.vhd               sequencer + program and data RAMs, the
                                      execution unit connected from outside
                                      (to_unit / from_unit)
  microprogram_assembler_pkg.vhd      schedule(), repeat(), place() : one
                                      program source for any configuration
  ram_connector_pkg.vhd               helpers for combining RAM ports
examples/
  boost_converter_pkg.vhd             an averaged boost converter model : its
                                      address map, program step and data
testbenches/                     fixed_execution_unit_tb checks
                                 fixed_mult_add, result_latency_tb measures
                                 its result latency, portable_program_tb runs
                                 one program source on four configurations ;
                                 the others run the sequencer and the float
                                 core
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
`a_sub_b_mpy_c`, `lp_filter` and the accumulator commands are in
`fixed_mult_add`; its accumulator is data width, `acc` adds c,
`get_acc_and_zero` writes the accumulator + c and zeroes it and
`check_and_saturate_acc` limits it. `mpy_acc` is an encoding with no
execution unit. There is no hazard detection in the hardware: a result is in the data
RAM only after the pipeline delay, so dependent instructions are spaced
with `nop`s, by hand or by `schedule()` below. A `jump` takes effect after
the three (two without the program RAM's output register) instructions that follow it, which are already fetched and run
on every round; a `program_end` among them ends the program.

## Result latency and the RAM collision

`execution_unit_pkg.fixed_point_result_latency(pre_add_register,
product_register, data_ram_output_register)` is how many instructions
after an instruction the first one that reads its result can be: 7, plus 1
for each of the pre-adder and product registers, minus 1 without the data
RAM's output register, for `fixed_mult_add`. `result_latency_tb` measures
it at the data RAM's ports.

`microprogram_core`'s `g_program_ram_output_register` and
`g_data_ram_output_register` (both on by default) set its RAMs' output
registers; the execution unit's `g_data_ram_output_register` must match the
data RAM's. Without them a RAM read takes one clock instead of two:

| without the | effect |
|---|---|
| data RAM's output register | the operands arrive a clock earlier: the result latency is one less |
| program RAM's output register | instructions are fetched a clock sooner: a `jump` has 2 delay slots instead of 3 (`microprogram_interface_pkg.jump_delay_slots()`), and a run one clock less |

The RAM's clock-to-output delay is then in the next stage's path: the
data RAM's into `fixed_dsp`'s request register, the program RAM's into the
sequencer's decode and program counter.

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
(instruction width, data width, radix, result latency, jump delay slots):

```vhdl
constant config : processor_config := (instruction_width => 36, data_width => 36, radix => 24,
    result_latency => fixed_point_result_latency(pre_add_register, product_register, data_ram_output_register),
    delay_slots    => jump_delay_slots(program_ram_output_register));

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
- `encode_data(entries, config, words)` makes a data RAM's contents from
  (address, value) pairs of reals, at the configuration's data width and
  radix, rounded half away from zero; `set_data()` writes pairs into
  existing contents and `to_fixed(value, config)` converts one value, up to
  60 bit data. Each fails on an address outside the RAM, an address given
  twice or a value that does not fit.

A model is written once as functions of an address map record, so the
same source places it anywhere in any configuration's RAMs.
`examples/boost_converter_pkg.vhd`:

```vhdl
constant boost : boost_converter_map := boost_converter_at(100); -- 100..109

program := place(program, 128, schedule(config, boost_converter_step(boost)) & mi(program_end));
data    := encode_data(boost_converter_data(boost, boost_converter_example), config, 1024);
```

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
a `jump` loop on `fixed_mult_add`, with and without the pre-adder and
product registers, with 32 and 36 bit data and instructions and a 128 word
program RAM, and checks every result against a model; `result_latency_tb`
and `portable_program_tb` check theirs too. The sequencer and float core
testbenches run without checking their results.
