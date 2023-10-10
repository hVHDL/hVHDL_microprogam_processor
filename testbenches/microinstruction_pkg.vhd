library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.real_to_fixed_pkg.all;

package microinstruction_pkg is

    type t_command is (program_end, nop, add , sub , mpy , mpy_add , div , ready , jump , ret , load_external, save_external, load_registers, save_registers);
    type counter_array is array (integer range 0 to 1) of natural;

    constant number_of_registers : natural := 9;
    constant register_bits : natural := 4;
    type stdarray is array (integer range 0 to 8) of std_logic_vector(19 downto 0);
    type realarray is array (integer range 0 to 8) of real;
    alias reg_array is stdarray;

    subtype comm is std_logic_vector(19 downto 16);
    subtype dest is std_logic_vector(15 downto 12);
    subtype arg1 is std_logic_vector(11 downto 8);
    subtype arg2 is std_logic_vector(7 downto 4);
    subtype arg3 is std_logic_vector(3 downto 0);

    subtype t_instruction is std_logic_vector(comm'high downto 0);
    type instruction_array is array (integer range 0 to 4) of t_instruction;
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

end package microinstruction_pkg;

package body microinstruction_pkg is
------------------------------------------------------------------------
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

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , 4));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , register_bits));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , register_bits));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , register_bits));
        instruction(arg3'range) := std_logic_vector(to_unsigned(argument3              , register_bits));

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

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , 4));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , register_bits));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , register_bits));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , register_bits));

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

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , 4));
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

        for i in array_of_reals'range loop
            retval(i) := to_fixed(array_of_reals(i), retval(0)'length, radix);
        end loop;

        return retval;
        
    end to_fixed;
------------------------------------------------------------------------
end package body microinstruction_pkg;
