
    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.dual_port_ram_pkg.read_pipeline_delay;

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

    -- fixed_mult_add and fixed_mult_acc : the pipeline stage, counted from
    -- the instruction's operand reads, in which a result is written ; the
    -- operands arrive read_pipeline_delay clocks after the reads, the
    -- fixed_dsp request is registered, the product takes 2 clocks and one
    -- more for each of the pre-adder and product registers
    function fixed_point_result_stage (pre_add_register, product_register : boolean) return natural;

    -- the instructions after an instruction that its result is not yet
    -- readable to : an instruction this many after it, or more, reads it.
    -- The ram takes the write a clock after the result stage and a read in
    -- the clock of the write is a port collision, so 2 more than the
    -- stage. result_latency_tb measures it.
    function fixed_point_result_latency (pre_add_register, product_register : boolean) return natural;

end package execution_unit_pkg;

package body execution_unit_pkg is

    function fixed_point_result_stage (pre_add_register, product_register : boolean) return natural is
    begin
        return read_pipeline_delay + 3
            + boolean'pos(pre_add_register) + boolean'pos(product_register);
    end fixed_point_result_stage;

    function fixed_point_result_latency (pre_add_register, product_register : boolean) return natural is
    begin
        return fixed_point_result_stage(pre_add_register, product_register) + 2;
    end fixed_point_result_latency;

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
        -- fixed_mult_add, fixed_mult_acc : fixed_dsp's g_product_register,
        -- one clock more from the operands to the result
        ;g_product_register  : boolean := false
       );
    port(
        clock : in std_logic
        ;unit_in : in execution_unit_in_record
        ;unit_out : out execution_unit_out_record
    );
end;
