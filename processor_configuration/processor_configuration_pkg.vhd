library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package processor_configuration_pkg is

    constant instruction_bit_width     : natural := 20;
    constant instruction_high          : natural := instruction_bit_width-1;

    constant number_of_registers       : natural := 5;
    constant number_of_pipeline_stages : natural := 6;

    constant register_bit_width        : natural := 20;
    constant register_high             : natural := register_bit_width-1;

    type t_command is (
        program_end,
        nop        ,
        add        ,
        sub        ,
        mpy        ,
        save       ,
        load
    );

end package processor_configuration_pkg;
