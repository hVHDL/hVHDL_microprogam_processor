
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

end package execution_unit_pkg;
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
       );
    port(
        clock : in std_logic
        ;unit_in : in execution_unit_in_record
        ;unit_out : out execution_unit_out_record
    );
end;
