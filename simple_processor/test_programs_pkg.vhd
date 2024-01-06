library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.real_to_fixed_pkg.all;

package test_programs_pkg is

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
        write_instruction(load , u    , input_address)  ,
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
------------------------------------------------------------------------
    function build_sw return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
        function to_fixed
        (
            number : real
        )
        return std_logic_vector 
        is
        begin
            return to_fixed(number, 20,19);
        end to_fixed;

        constant program : program_array := (
            low_pass_filter(gain_address => 100 , result_address => 101 , input_address => 102) &
            low_pass_filter(gain_address => 103 , result_address => 104 , input_address => 102) &
            low_pass_filter(gain_address => 105 , result_address => 106 , input_address => 102) &
            write_instruction(program_end) 
        );
------------------------------------------------------------------------
    begin

        assert program'length < 100 report "program needs to be less than 100 instructions" severity failure;

        for i in program'range loop
            retval(i) := program(i);
        end loop;
        retval(100) := to_fixed(0.1);
        retval(101) := to_fixed(0.0);
        retval(102) := to_fixed(0.5);

        retval(103) := to_fixed(0.2);
        retval(104) := to_fixed(0.0);

        retval(105) := to_fixed(0.4);
        retval(106) := to_fixed(0.0);
        retval(107) := x"0acdc";
            
        return retval;
        
    end build_sw;
------------------------------------------------------------------------
end package body test_programs_pkg;
