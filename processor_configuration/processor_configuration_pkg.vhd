library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    -- ram package defines instruction bit widths
    use work.ram_configuration_pkg.ram_bit_width;

package processor_configuration_pkg is

    function get_number_of_pipeline_stages ( number_of_stages : natural)
        return natural;

    constant instruction_bit_width     : natural := ram_bit_width;
    constant register_bit_width        : natural := ram_bit_width;

    constant number_of_registers       : natural := 5;
    constant number_of_pipeline_stages : natural := 17;


    type t_command is (
        program_end ,
        nop         ,
        add         ,
        sub         ,
        mpy         ,
        mpy_add     ,
        neg_mpy_add ,
        mpy_sub     ,

        save        ,
        load
    );

    subtype comm is std_logic_vector(31 downto 28);
    subtype dest is std_logic_vector(27 downto 21);
    subtype arg1 is std_logic_vector(20 downto 14);
    subtype arg2 is std_logic_vector(13 downto 7);
    subtype arg3 is std_logic_vector(6 downto 0);
    subtype long_arg is std_logic_vector(27 downto 0);

end package processor_configuration_pkg;

-- move this to separate source at some point

package body processor_configuration_pkg is


    function get_number_of_pipeline_stages
    (
        number_of_stages : natural
    )
    return natural
    is
        constant min_number_of_stages : natural := 17;
        variable retval : natural := number_of_stages;

    begin
        if number_of_stages < min_number_of_stages then
            retval := min_number_of_stages;
        end if;

        return retval;
    end get_number_of_pipeline_stages;

end package body processor_configuration_pkg;
