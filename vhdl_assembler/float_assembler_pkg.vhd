library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.processor_configuration_pkg.all;
    use work.float_alu_pkg.all;

package float_assembler_pkg is
------------------------------------------------------------------------
    function sub ( result_reg, left, right : natural)
        return program_array;

------------------------------------------------------------------------
    function add ( result_reg, left, right : natural)
        return program_array;

------------------------------------------------------------------------
    function multiply ( result_reg, left, right : natural)
        return program_array;

    function multiply_add ( result_reg, mpy1, mpy2, post_add : natural)
        return program_array;

------------------------------------------------------------------------
end package float_assembler_pkg;

package body float_assembler_pkg is
    ------------------------------
    -- move these to float library
    constant number_of_float_add_fills     : natural := add_pipeline_depth;
    constant number_of_float_mpy_fills     : natural := mult_pipeline_depth;
    constant number_of_float_mpy_add_fills : natural := alu_timing.madd_pipeline_depth;

    ------------------------------
    function sub
    (
        result_reg, left, right : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_add_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(sub, result_reg, left, right) & fill;
    end sub;
    ------------------------------
    function add
    (
        result_reg, left, right : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_add_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(add, result_reg, left, right) & fill;
    end add;
    ------------------------------
    function multiply
    (
        result_reg, left, right : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_mpy_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(mpy, result_reg, left, right) & fill;
    end multiply;
    ------------------------------
    function multiply_add
    (
        result_reg,mpy1, mpy2, post_add : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_mpy_add_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(mpy_add, result_reg, mpy1, mpy2, post_add) & fill;
    end multiply_add;
    ------------------------------
end package body float_assembler_pkg;
