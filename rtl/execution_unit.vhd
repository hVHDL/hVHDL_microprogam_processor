library ieee;
    use ieee.std_logic_1164.all;


    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

package execution_unit_pkg is

    type execution_unit_in_record is record
        data_read_out      : ram_read_out_array  ;
        instr_ram_read_out : ram_read_out_array ;
        instr_pipeline     : instruction_pipeline_array ;
    end record;

    type execution_unit_out_record is record
        data_read_in : ram_read_in_array  ;
        ram_write_in : ram_write_in_record ;
    end record;

    -- a data ram read's clocks : 2 with the ram's output register, 1 without
    function data_read_latency (data_ram_output_register : boolean) return natural;

    -- fixed_mult_add : the pipeline stage, counted from the instruction's
    -- operand reads, in which a result is written ; the operands arrive
    -- data_read_latency() clocks after the reads, the fixed_dsp request is
    -- registered, the product takes 2 clocks and one more for each of the
    -- pre-adder and product registers
    function fixed_point_result_stage (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true) return natural;

    -- the instructions after an instruction that its result is not yet
    -- readable to : an instruction this many after it, or more, reads it.
    -- The ram takes the write a clock after the result stage and a read in
    -- the clock of the write is a port collision, so 2 more than the
    -- stage. result_latency_tb measures it.
    function fixed_point_result_latency (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true) return natural;

    -- hVHDL_fixed_point's lut_divider and full_range_sqrt, from the
    -- request at the input to the ready : 6, 2 for each shifter stage (the
    -- input and output shifters have one each), 1 for the table ram's
    -- output register, and 2 for each of the dsp request, pre-adder and
    -- product registers (two fixed_dsps in series) ; 13 with 2 shifter
    -- stages and the ram output and dsp request registers
    function lut_divider_latency (pre_add_register, product_register : boolean;
        shifter_stages : positive := 2;
        ram_output_register, dsp_request_register : boolean := true) return natural;

    -- hVHDL_fixed_point's sine_calculator with its fixed_dsp, from the
    -- request to its ready : 4, and 1 for each of the table ram's output,
    -- the dsp request, the pre-adder and the product registers
    function sine_calculator_latency (pre_add_register, product_register : boolean;
        ram_output_register, dsp_request_register : boolean := true) return natural;

    -- fixed_math : the stage a quotient is written in, the operands are
    -- registered into the divider's request ; and its result latency, as
    -- fixed_point_result_latency()
    function fixed_math_result_stage (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true; divider_shifter_stages : positive := 2;
        math_ram_output_register, math_dsp_request_register : boolean := true) return natural;
    function fixed_math_result_latency (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true; divider_shifter_stages : positive := 2;
        math_ram_output_register, math_dsp_request_register : boolean := true) return natural;

    -- two execution units on one microprogram_core : the read requests of
    -- either, and the write of the one writing. One instruction issues a
    -- clock so only one unit reads at a time ; the program must not have
    -- both write in one clock, microprogram_assembler_pkg's schedule()
    -- keeps them apart
    function merge_units (a, b : execution_unit_out_record) return execution_unit_out_record;

end package execution_unit_pkg;

package body execution_unit_pkg is

    function data_read_latency (data_ram_output_register : boolean) return natural is
    begin
        return 1 + boolean'pos(data_ram_output_register);
    end data_read_latency;

    function fixed_point_result_stage (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true) return natural is
    begin
        return data_read_latency(data_ram_output_register) + 3
            + boolean'pos(pre_add_register) + boolean'pos(product_register);
    end fixed_point_result_stage;

    function fixed_point_result_latency (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true) return natural is
    begin
        return fixed_point_result_stage(pre_add_register, product_register, data_ram_output_register) + 2;
    end fixed_point_result_latency;

    function lut_divider_latency (pre_add_register, product_register : boolean;
        shifter_stages : positive := 2;
        ram_output_register, dsp_request_register : boolean := true) return natural is
    begin
        return 6 + 2 * shifter_stages + boolean'pos(ram_output_register)
            + 2 * boolean'pos(dsp_request_register)
            + 2 * boolean'pos(pre_add_register) + 2 * boolean'pos(product_register);
    end lut_divider_latency;

    function sine_calculator_latency (pre_add_register, product_register : boolean;
        ram_output_register, dsp_request_register : boolean := true) return natural is
    begin
        return 4 + boolean'pos(ram_output_register) + boolean'pos(dsp_request_register)
            + boolean'pos(pre_add_register) + boolean'pos(product_register);
    end sine_calculator_latency;

    function fixed_math_result_stage (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true; divider_shifter_stages : positive := 2;
        math_ram_output_register, math_dsp_request_register : boolean := true) return natural is
    begin
        return data_read_latency(data_ram_output_register) + 1
            + lut_divider_latency(pre_add_register, product_register, divider_shifter_stages,
                math_ram_output_register, math_dsp_request_register);
    end fixed_math_result_stage;

    function fixed_math_result_latency (pre_add_register, product_register : boolean;
        data_ram_output_register : boolean := true; divider_shifter_stages : positive := 2;
        math_ram_output_register, math_dsp_request_register : boolean := true) return natural is
    begin
        return fixed_math_result_stage(pre_add_register, product_register, data_ram_output_register,
            divider_shifter_stages, math_ram_output_register, math_dsp_request_register) + 2;
    end fixed_math_result_latency;

    function merge_units (a, b : execution_unit_out_record) return execution_unit_out_record is
        variable retval : a'subtype := a;
    begin
        for i in a.data_read_in'range loop
            if b.data_read_in(i).read_requested = '1' then
                retval.data_read_in(i) := b.data_read_in(i);
            end if;
        end loop;
        if b.ram_write_in.write_requested = '1' then
            retval.ram_write_in := b.ram_write_in;
        end if;
        return retval;
    end merge_units;

end package body execution_unit_pkg;
----------------------------------
----------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.execution_unit_pkg.all;

entity execution_unit is
    generic(
        g_arg1_port             : natural := 0
        ;g_arg2_port            : natural := 1
        ;g_arg3_port            : natural := 2
        ;g_radix               : natural := 14
        ;g_read_delays       : natural := 0
        ;g_read_out_delays   : natural := 0
        ;g_instruction_delay : natural := 9
        ;g_option            : string  := "hfloat"
        -- fixed_mult_add : fixed_dsp's g_pre_add_register, one more clock
        -- from the operands to the result
        ;g_pre_add_register  : boolean := false
        -- fixed_mult_add : fixed_dsp's g_product_register,
        -- one clock more from the operands to the result
        ;g_product_register  : boolean := false
        -- the data ram's output register, microprogram_core's
        -- g_data_ram_output_register : the operands arrive a clock earlier
        -- without it
        ;g_data_ram_output_register : boolean := true
        -- fixed_math : lut_divider's g_shifter_stages, more stages less
        -- logic in each, 2 clocks more per stage
        ;g_divider_shifter_stages : positive := 2
        -- fixed_math : its lookup tables' ram output registers and the
        -- registers on the requests to their fixed_dsps, each off takes
        -- clocks off the math latency
        ;g_math_ram_output_register  : boolean := true
        ;g_math_dsp_request_register : boolean := true
       );
    port(
        clock : in std_logic
        ;unit_in : in execution_unit_in_record
        ;unit_out : out execution_unit_out_record
    );
end;
