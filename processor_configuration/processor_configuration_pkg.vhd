library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package processor_configuration_pkg is

    constant instruction_bit_width     : natural := 20;
    constant register_bit_width        : natural := 20;

    constant number_of_registers       : natural := 5;
    constant number_of_pipeline_stages : natural := 6;


    type t_command is (
        program_end,
        nop        ,
        add        ,
        sub        ,
        mpy        ,
        save       ,
        load
    );

    subtype comm is std_logic_vector(19 downto 16);
    subtype dest is std_logic_vector(15 downto 12);
    subtype arg1 is std_logic_vector(11 downto 8);
    subtype arg2 is std_logic_vector(7 downto 4);
    subtype arg3 is std_logic_vector(3 downto 0);

end package processor_configuration_pkg;
