
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    -- encode() returns a program ram's initial contents
    use work.dual_port_ram_pkg.ram_array;

-- the instruction format follows the instruction's width : a 4 bit command
-- above four address fields of (width - 4) / 4 bits, dest, arg1, arg2 and
-- arg3, packed from bit 0 up, any spare bits on top. 32 bits gives 7 bit
-- fields in bits 31..0, the comm .. arg3 subtypes below. set_rpt and jump
-- take one argument in the arg1 .. arg3 fields. decode() and the get_
-- functions take the format from the length of the instruction they are
-- given ; op() writes 32 bit instructions, mi() and encode() any width.
package generic_microinstruction_pkg is
    generic(
            g_instruction_bit_width      : natural := 32
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
        ,mpy_acc
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
    -- an instruction can be wider than the fields below, which are in its
    -- low 32 bits : the pipeline takes the program ram's word width, and
    -- decode() and the get_ functions take an instruction of any width
    type instruction_pipeline_array is array (natural range <>) of std_logic_vector;
    
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
        input_register : std_logic_vector )
    return std_logic_vector;

------------------------------------------------------------------------
    function get_single_argument (
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
    constant command_bits : natural := 4;
    -- the address fields' width in an instruction of width bits
    function address_bits ( width : natural) return natural;
    -- set_rpt's and jump's argument, the three argument fields (at most 30)
    function single_argument_bits ( width : natural) return natural;

    -- an instruction before it is encoded for a width
    type microinstruction is record
        command : t_command;
        dest    : natural;
        arg1    : natural;
        arg2    : natural;
        arg3    : natural;
        single  : boolean; -- one argument, arg1, across the argument fields
    end record;
    type microprogram is array (natural range <>) of microinstruction;

    function mi ( command : t_command) return microinstruction;
    function mi ( command : t_command; dest, arg1, arg2, arg3 : natural) return microinstruction;
    -- set_rpt count, jump address
    function mi ( command : t_command; argument : natural) return microinstruction;

    function encode ( instruction : microinstruction; width : natural) return std_logic_vector;
    function encode ( program : microprogram; width : natural) return ram_array;
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

    -- bits low + bits - 1 downto low of an instruction of any range
    function field ( instruction : std_logic_vector; low, bits : natural) return natural is
    begin
        return to_integer(resize(shift_right(unsigned(instruction), low), bits));
    end field;

    function address_bits ( width : natural) return natural is
    begin
        return (width - command_bits) / 4;
    end address_bits;

    function single_argument_bits ( width : natural) return natural is
    begin
        return minimum(3 * address_bits(width), 30);
    end single_argument_bits;

    function mi ( command : t_command) return microinstruction is
    begin
        return (command => command, dest => 0, arg1 => 0, arg2 => 0, arg3 => 0, single => false);
    end mi;

    function mi ( command : t_command; dest, arg1, arg2, arg3 : natural) return microinstruction is
    begin
        return (command => command, dest => dest, arg1 => arg1, arg2 => arg2, arg3 => arg3, single => false);
    end mi;

    function mi ( command : t_command; argument : natural) return microinstruction is
    begin
        return (command => command, dest => 0, arg1 => argument, arg2 => 0, arg3 => 0, single => true);
    end mi;

    function encode ( instruction : microinstruction; width : natural) return std_logic_vector is
        constant a : natural := address_bits(width);
        variable retval : unsigned(width-1 downto 0);
    begin
        assert instruction.dest < 2**a and instruction.arg2 < 2**a and instruction.arg3 < 2**a
            and (instruction.arg1 < 2**a or (instruction.single and instruction.arg1 < 2**single_argument_bits(width)))
            report "an argument of " & t_command'image(instruction.command) & " does not fit "
                & integer'image(a) & " bit address fields" severity failure;
        retval := to_unsigned(t_command'pos(instruction.command), width);
        retval := shift_left(retval, a) + instruction.dest;
        if instruction.single then
            retval := shift_left(retval, 3*a) + instruction.arg1;
        else
            retval := shift_left(retval, a) + instruction.arg1;
            retval := shift_left(retval, a) + instruction.arg2;
            retval := shift_left(retval, a) + instruction.arg3;
        end if;
        return std_logic_vector(retval);
    end encode;

    function encode ( program : microprogram; width : natural) return ram_array is
        variable retval : ram_array(program'range)(width-1 downto 0);
    begin
        for i in program'range loop
            retval(i) := encode(program(i), width);
        end loop;
        return retval;
    end encode;

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
        input_register : std_logic_vector 
    )
    return natural
    is
        constant a : natural := address_bits(input_register'length);
    begin
        return field(input_register, 3*a, a);
    end get_dest;
------------------------------------------------------------------------
    function get_arg1
    (
        input_register : std_logic_vector 
    )
    return natural
    is
        constant a : natural := address_bits(input_register'length);
    begin
        return field(input_register, 2*a, a);
    end get_arg1;
------------------------------------------------------------------------
    function get_arg2
    (
        input_register : std_logic_vector 
    )
    return natural
    is
        constant a : natural := address_bits(input_register'length);
    begin
        return field(input_register, a, a);
    end get_arg2;
------------------------------------------------------------------------
    function get_arg3
    (
        input_register : std_logic_vector 
    )
    return natural
    is
        constant a : natural := address_bits(input_register'length);
    begin
        return field(input_register, 0, a);
    end get_arg3;
------------------------------------------------------------------------
    function get_long_argument
    (
        input_register : std_logic_vector 
    )
    return natural
    is
        constant a : natural := address_bits(input_register'length);
    begin
        return field(input_register, 0, minimum(4*a, 30));
    end get_long_argument;

------------------------------------------------------------------------
    function get_long_argument
    (
        input_register : std_logic_vector 
    )
    return std_logic_vector
    is
        constant bits : natural := minimum(4*address_bits(input_register'length), input_register'length);
    begin
        return std_logic_vector(resize(resize(unsigned(input_register), bits), input_register'length));
    end get_long_argument;

------------------------------------------------------------------------
    function get_single_argument
    (
        input_register : std_logic_vector 
    )
    return std_logic_vector
    is
        constant bits : natural := single_argument_bits(input_register'length);
    begin
        return std_logic_vector(resize(resize(unsigned(input_register), bits), input_register'length));
    end get_single_argument;

------------------------------------------------------------------------
    function get_single_argument
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return field(input_register, 0, single_argument_bits(input_register'length));
    end get_single_argument;
------------------------------------------------------------------------
    function get_instruction
    (
        input_register : std_logic_vector 
    )
    return integer
    is
        constant a : natural := address_bits(input_register'length);
    begin
        return field(input_register, 4*a, command_bits);
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
