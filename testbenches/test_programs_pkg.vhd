library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;

package test_programs_pkg is

    function get_dummy return program_array;
    function get_pipelined_low_pass_filter return program_array;

    function low_pass_filter (
        gain_address   : natural;
        result_address : natural;
        input_address  : natural)
    return program_array;

    function build_sw return ram_array;

end package test_programs_pkg;

package body test_programs_pkg is

    function low_pass_filter
    (
        gain_address   : natural;
        result_address : natural;
        input_address  : natural
    )
    return program_array
    is
        constant y    : natural := 1;
        constant g    : natural := 2;
        constant temp : natural := 3;
        constant u    : natural := 4;

        constant program : program_array := (
        write_instruction(load , y    , result_address) ,
        write_instruction(load , g    , gain_address)   ,
        write_instruction(load , u    , input_address)   ,
        write_instruction(nop) ,
        write_instruction(sub  , temp , u , y) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(mpy  , temp , temp , g) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(add  , y, temp , y),
        write_instruction(nop) ,
        write_instruction(nop) ,
        write_instruction(save, y, result_address)
    );
    begin
        return program;
        
    end low_pass_filter;

    constant program : program_array := (
        low_pass_filter(gain_address => 100 , result_address => 101 , input_address => 102) ,
        low_pass_filter(gain_address => 103 , result_address => 104 , input_address => 102) ,
        low_pass_filter(gain_address => 105 , result_address => 106 , input_address => 102) ,
        write_instruction(program_end) 
    );
------------------------------------------------------------------------

------------------------------------------------------------------------
    function build_sw return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;
        retval(100) := std_logic_vector(to_signed(integer(0.1*2**19),20));
        retval(101) := std_logic_vector(to_signed(integer(0.0*2**19),20));
        retval(102) := std_logic_vector(to_signed(integer(0.5*2**19),20));

        retval(103) := std_logic_vector(to_signed(integer(0.2*2**19),20));
        retval(104) := std_logic_vector(to_signed(integer(0.0*2**19),20));

        retval(105) := std_logic_vector(to_signed(integer(0.3*2**19),20));
        retval(106) := std_logic_vector(to_signed(integer(0.0*2**19),20));
            
        return retval;
        
    end build_sw;
------------------------------------------------------------------------
    function get_pipelined_low_pass_filter return program_array is
        constant y            : integer := 0;
        constant u            : integer := 1;
        constant temp         : integer := 2;
        constant g            : integer := 3;
        constant result_name  : integer := 4;

        constant lpf : program_array := (
            write_instruction(sub   , temp         , u    , y)    ,
            write_instruction(nop)  ,
            write_instruction(nop)  ,
            write_instruction(mpy   , temp         , temp , g)    ,
            write_instruction(stall , 1)           ,
            write_instruction(add   , y            , y    , temp) ,
            write_instruction(nop)  ,
            write_instruction(nop)  ,
            write_instruction(ready , result_name) 
        );

    begin

        return lpf;
        
    end get_pipelined_low_pass_filter;
------------------------------------------------------------------------
    function get_dummy return program_array
    is
        constant dummy : program_array := (
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop));
            -- write_instruction(program_end));

        variable returned_code : program_array(0 to dummy'length-1);
    begin

        returned_code := dummy;
        
        return returned_code;
    end get_dummy;
------------------------------------------------------------------------
end package body test_programs_pkg;
