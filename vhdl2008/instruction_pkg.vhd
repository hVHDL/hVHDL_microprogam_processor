
    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

package instruction_pkg is

    type instruction_in_record is record
        data_read_out      : ram_read_out_array  ;
        instr_ram_read_out : ram_read_out_array ;
        instr_pipeline     : instruction_pipeline_array ;
    end record;

    type instruction_out_record is record
        data_read_in : ram_read_in_array  ;
        ram_write_in : ram_write_in_record ;
    end record;

end package instruction_pkg;
----------------------------------
----------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.instruction_pkg.all;

entity instruction is
    generic(
        arg1_mem             : natural := 0
        ;arg2_mem            : natural := 1
        ;arg3_mem            : natural := 2
        ;radix               : natural := 14
        ;g_read_delays       : natural := 0
        ;g_read_out_delays   : natural := 0
        ;g_instruction_delay : natural := 9
        ;g_option            : string  := "hfloat"
       );
    port(
        clock : in std_logic
        ;instruction_in : in instruction_in_record
        ;instruction_out : out instruction_out_record
    );
end;
