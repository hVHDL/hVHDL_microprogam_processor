library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package testprogram_pkg is

    type t_command is (add, sub, mpy, mpy_add, div, ready, program_end,nop);
    type command_array is array (t_command range t_command'left to t_command'right) of natural;
    type realarray is array (integer range 0 to 7) of real;

    subtype t_instruction is std_logic_vector(16 downto 0);
    type program_array is array (natural range <>) of t_instruction;

    subtype comm is std_logic_vector(16 downto 13);
    subtype dest is std_logic_vector(12 downto 10);
    subtype arg1 is std_logic_vector(9 downto 7);
    subtype arg2 is std_logic_vector(6 downto 4);
    subtype arg3 is std_logic_vector(3 downto 1);

    procedure create_processor (
        signal pgm_counter : inout natural;
        instruction : in std_logic_vector;
        signal reg  : inout realarray);

    function write_instruction ( command : in t_command)
        return std_logic_vector;
------------------------------------------------------------------------
    function write_instruction (
        command     : in t_command;
        destination : in natural range 0 to 7;
        argument1   : in natural range 0 to 7;
        argument2   : in natural range 0 to 7)
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

end package testprogram_pkg;

package body testprogram_pkg is
------------------------------------------------------------------------
    function write_instruction
    (
        command     : in t_command;
        destination : in natural range 0 to 7;
        argument1   : in natural range 0 to 7;
        argument2   : in natural range 0 to 7;
        argument3   : in natural range 0 to 7
    )
    return std_logic_vector
    is
        variable instruction : t_instruction;
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , 4));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , 3));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , 3));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , 3));
        instruction(arg3'range) := std_logic_vector(to_unsigned(argument3              , 3));

        return instruction;
        
    end write_instruction;
------------------------------------------------------------------------
    function write_instruction
    (
        command     : in t_command;
        destination : in natural range 0 to 7;
        argument1   : in natural range 0 to 7;
        argument2   : in natural range 0 to 7
    )
    return std_logic_vector
    is
        variable instruction : t_instruction;
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , 4));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , 3));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , 3));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , 3));

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
        variable instruction : t_instruction;
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
    procedure create_processor
    (
        signal pgm_counter : inout natural;
        instruction : in std_logic_vector;
        signal reg  : inout realarray
    )
    is
    begin
        if decode(instruction) /= program_end then
            pgm_counter <= pgm_counter + 1;
        end if;
        CASE decode(instruction) is
            when add =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) + reg(get_arg2(instruction));
            when sub =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) - reg(get_arg2(instruction));
            when mpy =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction));
            when mpy_add =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction));
            when div =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) / reg(get_arg2(instruction));
            when program_end =>
            when ready => -- do nothing
            when nop   => --do nothing
        end CASE;
        
    end create_processor;
------------------------------------------------------------------------

end package body testprogram_pkg;
