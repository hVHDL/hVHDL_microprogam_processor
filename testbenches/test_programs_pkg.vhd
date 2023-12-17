library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;

package test_programs_pkg is

    function get_sos_filter return program_array;
    function get_dummy return program_array;
    function get_pipelined_low_pass_filter return program_array;

end package test_programs_pkg;

package body test_programs_pkg is

------------------------------------------------------------------------
    function get_pipelined_low_pass_filter return program_array is
        constant y            : integer := 0;
        constant u            : integer := 1;
        constant temp         : integer := 2;
        constant g            : integer := 3;
        constant result_name  : integer := 4;
        constant reg_location : integer := 5;

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
            -- write_instruction(save_registers, reg_location)
        );

    begin

        return lpf;
        
    end get_pipelined_low_pass_filter;
------------------------------------------------------------------------
    function get_sos_filter return program_array
    is
        constant y  : integer := 0;
        constant u  : integer := 1;
        constant x1 : integer := 2;
        constant x2 : integer := 3;
        constant b0 : integer := 4;
        constant b1 : integer := 5;
        constant b2 : integer := 6;
        constant a1 : integer := 7;
        constant a2 : integer := 8;

        constant sos_program : program_array := (
            write_instruction(mpy_add , y  , b0 , u   , x1) ,
            write_instruction(mpy_add , x1 , b1 , u   , x2) ,
            write_instruction(mpy     , x2 , b2 , u ) ,
            write_instruction(mpy_add , x1 , a1 , y   , x1) ,
            write_instruction(mpy_add , x2 , a2 , y   , x2) ,
            write_instruction(ready)  ,
            write_instruction(program_end),
            write_instruction(program_end),
            write_instruction(program_end)
        );
        variable returned_code : program_array(0 to sos_program'length-1);
    begin

        returned_code := sos_program;
        
        return returned_code;
    end get_sos_filter;

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
            write_instruction(program_end));

        variable returned_code : program_array(0 to dummy'length-1);
    begin

        returned_code := dummy;
        
        return returned_code;
    end get_dummy;
------------------------------------------------------------------------
end package body test_programs_pkg;
