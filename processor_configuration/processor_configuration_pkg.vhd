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
    constant number_of_pipeline_stages : natural := get_number_of_pipeline_stages(6);


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

-- move this to separate source at some point

package body processor_configuration_pkg is

    use work.normalizer_pipeline_pkg.normalizer_pipeline_configuration;
    use work.denormalizer_pipeline_pkg.pipeline_configuration;

    function get_number_of_pipeline_stages
    (
        number_of_stages : natural
    )
    return natural
    is
        constant min_number_of_stages : natural := normalizer_pipeline_configuration + pipeline_configuration + 3;
        variable retval : natural := number_of_stages;

    begin
        if number_of_stages < min_number_of_stages then
            retval := min_number_of_stages;
        end if;

        return retval;
    end get_number_of_pipeline_stages;

end package body processor_configuration_pkg;
