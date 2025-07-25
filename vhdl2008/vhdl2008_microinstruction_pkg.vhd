
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package generic_microinstruction_pkg is
    generic(
            g_instruction_bit_width     : natural := 32
            ;g_data_bit_width            : natural := 32
            ;g_number_of_registers       : natural := 5
            ;g_number_of_pipeline_stages : natural := 10
    );

    constant instruction_bit_width     : natural := g_instruction_bit_width    ;
    constant data_bit_width            : natural := g_data_bit_width       ;
    constant number_of_registers       : natural := g_number_of_registers      ;
    constant number_of_pipeline_stages : natural := g_number_of_pipeline_stages;

    type t_command is (
        mpy_add     
        ,mpy_sub     
        ,neg_mpy_add 
        ,neg_mpy_sub
        ,a_add_b_mpy_c
        ,a_sub_b_mpy_c
        ,lp_filter
        ,program_end 
        ,nop         
        ,set_rpt
        ,jump
        ,acc
        ,get_acc_and_zero
        ,check_and_saturate_acc
        ,res9
        ,res10
    );
    function get(instr : t_command) return std_logic_vector;
    function sub(dest, a, b : natural) return std_logic_vector;
    function add(dest, a, b : natural) return std_logic_vector;
    function mpy(dest, a, b : natural) return std_logic_vector;
    function accum(a : natural) return std_logic_vector;
    function acc_get_and_zero(dest , a : natural) return std_logic_vector;
    function set(dest, a : natural) return std_logic_vector;

    subtype comm is std_logic_vector(31 downto 28);
    subtype dest is std_logic_vector(27 downto 21);
    subtype arg1 is std_logic_vector(20 downto 14);
    subtype arg2 is std_logic_vector(13 downto 7);
    subtype arg3 is std_logic_vector(6 downto 0);
    subtype long_arg is std_logic_vector(27 downto 0);

    type reg_array                  is array (natural range 0 to number_of_registers-1) of std_logic_vector(data_bit_width-1 downto 0);
    type instruction_pipeline_array is array (natural range 0 to number_of_pipeline_stages-1) of std_logic_vector(instruction_bit_width-1 downto 0);
    
    subtype t_instruction           is std_logic_vector(instruction_bit_width-1 downto 0);
    type program_array              is array (natural range <>) of t_instruction;

------------------------------------------------------------------------
    -- these are used to help with using internal variables in microprograms
    type variable_array is array (natural range <>) of integer;

    function init_variables ( number_of_variables : natural)
        return variable_array;

    function "+" ( left : variable_array; right : integer)
        return variable_array;

------------------------------------------------------------------------
    function op ( command : in t_command)
        return t_instruction;
------------------------------------------------------------------------
    function op (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural ;
        argument2   : in natural )
    return t_instruction;
----------------
    function op (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural ;
        argument2   : in natural ;
        argument3   : in natural )
    return t_instruction;
----------------
    function op (
        command     : in t_command;
        long_argument : in natural)
    return t_instruction;

------------------------------------------------------------------------
    function op (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural)
    return t_instruction;

------------------------------------------------------------------------
    function get_single_argument (
        input_register : t_instruction )
    return t_instruction;

------------------------------------------------------------------------
    function get_single_argument (
        input_register : t_instruction )
    return natural;
------------------------------------------------------------------------
    function get_instruction ( input_register : t_instruction )
        return integer;
------------------------------------------------------------------------
    function decode ( number : natural)
        return t_command;
------------------------------------------------------------------------
    function decode ( number : t_instruction)
        return t_command;
------------------------------------------------------------------------
    function get_dest ( input_register : t_instruction )
        return natural;
------------------------------------------------------------------------
    function get_arg1 ( input_register : t_instruction )
        return natural;
------------------------------------------------------------------------
    function get_arg2 ( input_register : t_instruction )
        return natural;
------------------------------------------------------------------------
    function get_arg3 ( input_register : t_instruction )
        return natural;
------------------------------------------------------------------------
    function get_long_argument ( input_register : t_instruction )
        return natural;
    function get_long_argument ( input_register : t_instruction )
        return t_instruction;
------------------------------------------------------------------------
    function pipelined_block ( program : program_array)
        return program_array;
------------------------------------------------------------------------
    function pipelined_block ( instruction : t_instruction)
        return program_array;
------------------------------------------------------------------------
end package generic_microinstruction_pkg;

package body generic_microinstruction_pkg is
------------------------------------------------------------------------
    constant ref : std_logic_vector(dest'low-1 downto 0) := (others => '0');

    ---------------
    function op
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

        instruction(comm'range) := get(command);
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , arg1'length));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , arg2'length));
        instruction(arg3'range) := std_logic_vector(to_unsigned(argument3              , arg3'length));

        return instruction;
        
    end op;
------------------------------------------------------------------------
    function op
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

        instruction(comm'range) := get(command);
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , arg1'length));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , arg2'length));

        return instruction;
        
    end op;

------------------------------------------------------------------------
    function op
    (
        command     : in t_command;
        destination : in natural ;
        argument1   : in natural
    )
    return t_instruction
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range)        := get(command);
        instruction(dest'range)        := std_logic_vector(to_unsigned(destination            , dest'length));
        instruction(dest'low-1 downto 0) := std_logic_vector(to_unsigned(argument1            , ref'length));

        return instruction;
        
    end op;
------------------------------------------------------------------------
    function op
    (
        command     : in t_command;
        long_argument : in natural
    )
    return t_instruction
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        instruction(comm'range) := get(command);
        instruction(long_arg'range) := std_logic_vector(to_unsigned(long_argument, long_arg'length));

        return instruction;
        
    end op;
------------------------------------------------------------------------
    function op
    (
        command : in t_command
    )
    return t_instruction
    is
        variable instruction : t_instruction := (others=>'0');
    begin

        return op(command, 3,0,1);
        
    end op;
------------------------------------------------------------------------
    function get_dest
    (
        input_register : t_instruction 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(dest'range)));
    end get_dest;
------------------------------------------------------------------------
    function get_arg1
    (
        input_register : t_instruction 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg1'range)));
    end get_arg1;
------------------------------------------------------------------------
    function get_arg2
    (
        input_register : t_instruction 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg2'range)));
    end get_arg2;
------------------------------------------------------------------------
    function get_arg3
    (
        input_register : t_instruction 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg3'range)));
    end get_arg3;
------------------------------------------------------------------------
    function get_long_argument
    (
        input_register : t_instruction 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(comm'low-1 downto 0)));
        
    end get_long_argument;

------------------------------------------------------------------------
    function get_long_argument
    (
        input_register : t_instruction 
    )
    return t_instruction
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(comm'low-1 downto 0) := input_register(comm'low-1 downto 0);
        return retval;
        
    end get_long_argument;

------------------------------------------------------------------------
    function get_single_argument
    (
        input_register : t_instruction 
    )
    return t_instruction
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(ref'range) := input_register(ref'range);
        return retval;
        
    end get_single_argument;

------------------------------------------------------------------------
    function get_single_argument
    (
        input_register : t_instruction 
    )
    return natural
    is
        variable retval : t_instruction := (others => '0');
    begin
        retval(ref'range) := input_register(ref'range);
        return to_integer(unsigned(retval));
        
    end get_single_argument;
------------------------------------------------------------------------
    function get_instruction
    (
        input_register : t_instruction 
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
        number : t_instruction
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
        variable retval : program_array(0 to number_of_pipeline_stages-1) := (others => op(nop));
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
----
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
    -- move these out of here
    --
    function get(instr : t_command) return std_logic_vector is
    begin
        return std_logic_vector(to_unsigned(t_command'pos(instr) , comm'length));
    end get;
    --
    function sub(dest, a, b : natural) return std_logic_vector is
    begin
        return op(mpy_sub, dest, 1, a, b);
    end sub;

    --
    function add(dest, a, b : natural) return std_logic_vector is
    begin
        return op(mpy_add, dest, 1, a, b);
    end add;

    --
    function mpy(dest, a, b : natural) return std_logic_vector is
    begin
        return op(mpy_add, dest, a, b, 0);
    end mpy;

    function accum(a : natural) return std_logic_vector is
    begin
        return op(acc, 0, a);
    end accum;

    function acc_get_and_zero(dest , a : natural) return std_logic_vector is
    begin
        return op(get_acc_and_zero, dest, a);
    end acc_get_and_zero;

    function set(dest, a : natural) return std_logic_vector is
    begin
        return op(mpy_add, dest, a, 1, 0);
    end set;


end package body generic_microinstruction_pkg;

package microinstruction_pkg is new work.generic_microinstruction_pkg 
    generic map(g_number_of_pipeline_stages => 8);
