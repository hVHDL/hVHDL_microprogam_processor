library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.real_to_fixed_pkg.all;
    use work.multi_port_ram_pkg.all;

package microinstruction_pkg is
    -- TODO, move to configuration
    constant number_of_registers       : natural := 5;
    constant number_of_pipeline_stages : natural := 6;
    constant instruction_bit_width     : natural := 20;
    constant instruction_high          : natural := instruction_bit_width-1;
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

    type reg_array is array (integer range 0 to number_of_registers-1) of std_logic_vector(register_high downto 0);
    type realarray is array (natural range <>) of real;

    subtype comm is std_logic_vector(19 downto 16);
    subtype dest is std_logic_vector(15 downto 12);
    subtype arg1 is std_logic_vector(11 downto 8);
    subtype arg2 is std_logic_vector(7 downto 4);
    subtype arg3 is std_logic_vector(3 downto 0);

    subtype t_instruction is std_logic_vector(comm'high downto 0);
    type instruction_array is array (integer range 0 to number_of_pipeline_stages-1) of t_instruction;
    type program_array is array (natural range <>) of t_instruction;

    function to_fixed (
        array_of_reals : realarray;
        radix  : natural )
    return reg_array;

------------------------------------------------------------------------
    function write_instruction ( command : in t_command)
        return std_logic_vector;
------------------------------------------------------------------------
    function write_instruction (
        command     : in t_command;
        destination : in natural range 0 to number_of_registers-1;
        argument1   : in natural range 0 to number_of_registers-1;
        argument2   : in natural range 0 to number_of_registers-1)
    return std_logic_vector;
----------------
    function write_instruction (
        command     : in t_command;
        destination : in natural range 0 to number_of_registers-1;
        argument1   : in natural range 0 to number_of_registers-1;
        argument2   : in natural range 0 to number_of_registers-1;
        argument3   : in natural range 0 to number_of_registers-1)
    return std_logic_vector;
----------------
    function write_instruction (
        command     : in t_command;
        long_argument : in natural)
    return std_logic_vector;

    function write_instruction (
        command     : in t_command;
        destination : in natural range 0 to number_of_registers-1;
        argument1   : in natural)
    return std_logic_vector;

    function get_sigle_argument (
        input_register : std_logic_vector )
    return std_logic_vector;

    function get_sigle_argument (
        input_register : std_logic_vector )
    return natural;
------------------------------------------------------------------------
    function get_instruction ( input_register : std_logic_vector )
        return integer;
------------------------------------------------------------------------
    function decode ( number : natural)
        return t_command;
------------------------------------------------------------------------
    function decode ( number : std_logic_vector)
        return t_command;
------------------------------------------------------------------------
    function get_dest ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------
    function get_arg1 ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------
    function get_arg2 ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------
    function get_arg3 ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------
    function get_long_argument ( input_register : std_logic_vector )
        return natural;
    function get_long_argument ( input_register : std_logic_vector )
        return std_logic_vector;
------------------------------------------------------------------------
    function write_register_values_to_ram (
        ram_to_be_intialized : ram_array;
        register_init_values : reg_array;
        end_address : natural)
    return ram_array;
------------------------------------------------------------------------
end package microinstruction_pkg;

package body microinstruction_pkg is
------------------------------------------------------------------------
    constant ref : std_logic_vector(dest'low-1 downto 0) := (others => '0');

    function write_instruction
    (
        command     : in t_command;
        destination : in natural range 0 to number_of_registers-1;
        argument1   : in natural range 0 to number_of_registers-1;
        argument2   : in natural range 0 to number_of_registers-1;
        argument3   : in natural range 0 to number_of_registers-1
    )
    return std_logic_vector
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , comm'length));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , arg1'length));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , arg2'length));
        instruction(arg3'range) := std_logic_vector(to_unsigned(argument3              , arg3'length));

        return instruction;
        
    end write_instruction;
------------------------------------------------------------------------
    function write_instruction
    (
        command     : in t_command;
        destination : in natural range 0 to number_of_registers-1;
        argument1   : in natural range 0 to number_of_registers-1;
        argument2   : in natural range 0 to number_of_registers-1
    )
    return std_logic_vector
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , comm'length));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , arg1'length));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , arg2'length));

        return instruction;
        
    end write_instruction;

    function write_instruction
    (
        command     : in t_command;
        destination : in natural range 0 to number_of_registers-1;
        argument1   : in natural
    )
    return std_logic_vector
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range)        := std_logic_vector(to_unsigned(t_command'pos(command) , comm'length));
        instruction(dest'range)        := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(dest'low-1 downto 0) := std_logic_vector(to_unsigned(argument1            , ref'length));

        return instruction;
        
    end write_instruction;
------------------------------------------------------------------------
    function write_instruction
    (
        command     : in t_command;
        long_argument : in natural
    )
    return std_logic_vector
    is
        variable instruction : t_instruction := (others=>'0');
        constant get_long_argument_range : std_logic_vector(comm'right-1 downto 0) := (others => '0');
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , comm'length));
        instruction(get_long_argument_range'range) := std_logic_vector(to_unsigned(long_argument, get_long_argument_range'length));

        return instruction;
        
    end write_instruction;
------------------------------------------------------------------------
------------------------------------------------------------------------
    function write_instruction
    (
        command : in t_command
    )
    return std_logic_vector
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        return write_instruction(command, 3,0,1);
        
    end write_instruction;
------------------------------------------------------------------------
    function get_dest
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(dest'range)));
    end get_dest;
------------------------------------------------------------------------
    function get_arg1
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg1'range)));
    end get_arg1;
------------------------------------------------------------------------
    function get_arg2
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg2'range)));
    end get_arg2;
------------------------------------------------------------------------
    function get_arg3
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg3'range)));
    end get_arg3;
------------------------------------------------------------------------
    function get_long_argument
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(comm'low-1 downto 0)));
        
    end get_long_argument;

    function get_long_argument
    (
        input_register : std_logic_vector 
    )
    return std_logic_vector
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(comm'low-1 downto 0) := input_register(comm'low-1 downto 0);
        return retval;
        
    end get_long_argument;

    function get_sigle_argument
    (
        input_register : std_logic_vector 
    )
    return std_logic_vector
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(ref'range) := input_register(ref'range);
        return retval;
        
    end get_sigle_argument;

    function get_sigle_argument
    (
        input_register : std_logic_vector 
    )
    return natural
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(ref'range) := input_register(ref'range);
        return to_integer(unsigned(retval));
        
    end get_sigle_argument;
------------------------------------------------------------------------
------------------------------------------------------------------------
    function get_instruction
    (
        input_register : std_logic_vector 
    )
    return integer
    is
    begin
        return to_integer(unsigned(input_register(comm'range)));
    end get_instruction;
------------------------------------------------------------------------
    function decode
    (
        number : natural
    )
    return t_command
    is
    begin
        return t_command'val(number);
    end decode;
------------------------------------------------------------------------
    function decode
    (
        number : std_logic_vector
    )
    return t_command
    is
    begin
        return decode(get_instruction(number));
    end decode;
------------------------------------------------------------------------
    function to_fixed
    (
        array_of_reals : realarray;
        radix  : natural 
    )
    return reg_array
    is
        variable retval : reg_array;
        
    begin

        if array_of_reals'length >= retval'length then
            for i in retval'range loop
                retval(i) := to_fixed(array_of_reals(i), retval(0)'length, radix);
            end loop;
        else
            for i in array_of_reals'range loop
                retval(i) := to_fixed(array_of_reals(i), retval(0)'length, radix);
            end loop;
        end if;

        return retval;
        
    end to_fixed;
------------------------------------------------------------------------

    function write_register_values_to_ram
    (
        ram_to_be_intialized : ram_array;
        register_init_values : reg_array;
        end_address : natural
    )
    return ram_array
    is
        variable retval : ram_array := ram_to_be_intialized;
    begin

        for i in end_address-reg_array'high to end_address loop
            retval(i) := register_init_values(i-(end_address-reg_array'high));
        end loop;

        return retval;
        
    end write_register_values_to_ram;
------------------------------------------------------------------------
end package body microinstruction_pkg;
