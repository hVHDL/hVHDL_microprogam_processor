library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.real_to_fixed_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.processor_configuration_pkg.all;

package microinstruction_pkg is

    type reg_array is array (integer range 0 to number_of_registers-1) of std_logic_vector(register_bit_width-1 downto 0);
    subtype t_instruction is std_logic_vector(instruction_bit_width-1 downto 0);
    type instruction_pipeline_array is array (integer range 0 to number_of_pipeline_stages-1) of t_instruction;
    type program_array is array (natural range <>) of t_instruction;


------------------------------------------------------------------------
    -- these are used to help with using internal variables in microprograms
    type variable_array is array (natural range <>) of integer;

    function init_variables ( number_of_variables : natural)
        return variable_array;

    function "+" ( left : variable_array; right : integer)
        return variable_array;

------------------------------------------------------------------------
    function write_instruction ( command : in t_command)
        return t_instruction;
------------------------------------------------------------------------
    function write_instruction (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural ;
        argument2   : in natural )
    return t_instruction;
----------------
    function write_instruction (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural ;
        argument2   : in natural ;
        argument3   : in natural )
    return t_instruction;
----------------
    function write_instruction (
        command     : in t_command;
        long_argument : in natural)
    return t_instruction;

------------------------------------------------------------------------
    function write_instruction (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural)
    return t_instruction;

------------------------------------------------------------------------
    function get_sigle_argument (
        input_register : std_logic_vector )
    return t_instruction;

------------------------------------------------------------------------
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
        return t_instruction;
------------------------------------------------------------------------
    function pipelined_block ( program : program_array)
        return program_array;
------------------------------------------------------------------------
    function pipelined_block ( instruction : t_instruction)
        return program_array;
------------------------------------------------------------------------
end package microinstruction_pkg;

package body microinstruction_pkg is
------------------------------------------------------------------------
    constant ref : std_logic_vector(dest'low-1 downto 0) := (others => '0');

    function write_instruction
    (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural ;
        argument2   : in natural ;
        argument3   : in natural 
    )
    return t_instruction
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
        destination : in natural ;
        argument1   : in natural ;
        argument2   : in natural 
    )
    return t_instruction
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , comm'length));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , arg1'length));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , arg2'length));

        return instruction;
        
    end write_instruction;

------------------------------------------------------------------------
    function write_instruction
    (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural
    )
    return t_instruction
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
    return t_instruction
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , comm'length));
        instruction(long_arg'range) := std_logic_vector(to_unsigned(long_argument, long_arg'length));

        return instruction;
        
    end write_instruction;
------------------------------------------------------------------------
    function write_instruction
    (
        command : in t_command
    )
    return t_instruction
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

------------------------------------------------------------------------
    function get_long_argument
    (
        input_register : std_logic_vector 
    )
    return t_instruction
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(comm'low-1 downto 0) := input_register(comm'low-1 downto 0);
        return retval;
        
    end get_long_argument;

------------------------------------------------------------------------
    function get_sigle_argument
    (
        input_register : std_logic_vector 
    )
    return t_instruction
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(ref'range) := input_register(ref'range);
        return retval;
        
    end get_sigle_argument;

------------------------------------------------------------------------
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
    function pipelined_block
    (
        program : program_array
    )
    return program_array
    is
        variable retval : program_array(0 to number_of_pipeline_stages-1) := (others => write_instruction(nop));
    begin

        if program'length < retval'length then
            for i in program'range loop
                retval(i) := program(i);
            end loop;
            return retval;
        else
            return program;
        end if;
        
    end pipelined_block;
------------------------------------------------------------------------
    function pipelined_block
    (
        instruction : t_instruction
    )
    return program_array
    is
    begin
        return pipelined_block(program_array'(0=>instruction));
    end pipelined_block;
------------------------------------------------------------------------
    function "+"
    (
        left : variable_array; right : integer
    )
    return variable_array
    is
        variable retval : variable_array(left'range);
    begin
        for i in left'range loop
            retval(i) := left(i) + right;
        end loop;
        return retval;
    end "+";
    function init_variables
    (
        number_of_variables : natural
    )
    return variable_array
    is
        variable retval : variable_array(0 to number_of_variables-1) := (others => 0);
    begin
        for i in retval'range loop
            retval(i) := i;
        end loop;

        return retval;
        
    end init_variables;
------------------------------------------------------------------------
end package body microinstruction_pkg;
