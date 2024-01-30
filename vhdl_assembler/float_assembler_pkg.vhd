library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.processor_configuration_pkg.all;

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

------------------------------------------------------------------------
end package float_assembler_pkg;

package body float_assembler_pkg is
    ------------------------------
    use work.normalizer_pkg.number_of_normalizer_pipeline_stages;
    constant normalizer_fill : program_array(0 to number_of_normalizer_pipeline_stages-1) := (others => write_instruction(nop));

    ------------------------------
    use work.denormalizer_pkg.number_of_denormalizer_pipeline_stages;
    constant denormalizer_fill : program_array(0 to number_of_denormalizer_pipeline_stages-1) := (others => write_instruction(nop));
    -- move these to float library
    constant number_of_float_add_fills : natural := 2;
    constant number_of_float_mpy_fills : natural := 3;

    ------------------------------
    function sub
    (
        result_reg, left, right : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_add_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(sub, result_reg, left, right) & normalizer_fill & denormalizer_fill & fill;
    end sub;
    ------------------------------
    function add
    (
        result_reg, left, right : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_add_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(add, result_reg, left, right) & normalizer_fill & denormalizer_fill & fill;
    end add;
    ------------------------------
    function multiply
    (
        result_reg, left, right : natural
    )
    return program_array is
        constant fill : program_array(0 to number_of_float_mpy_fills) := (others => write_instruction(nop));
    begin
        return write_instruction(mpy, result_reg, left, right) & normalizer_fill & fill;
    end multiply;
    ------------------------------
end package body float_assembler_pkg;
