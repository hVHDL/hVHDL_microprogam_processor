library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.processor_configuration_pkg.all;

package float_assembler_pkg is

        function sub ( result_reg, left, right : natural)
            return program_array;

        function add ( result_reg, left, right : natural)
            return program_array;

        function multiply ( result_reg, left, right : natural)
            return program_array;

end package float_assembler_pkg;

package body float_assembler_pkg is
        ------------------------------
        use work.normalizer_pkg.number_of_normalizer_pipeline_stages;
        constant normalizer_fill : program_array(0 to number_of_normalizer_pipeline_stages-1) := (others => write_instruction(nop));

        ------------------------------
        use work.denormalizer_pkg.number_of_denormalizer_pipeline_stages;
        constant denormalizer_fill : program_array(0 to number_of_denormalizer_pipeline_stages-1) := (others => write_instruction(nop));

        ------------------------------
        function sub
        (
            result_reg, left, right : natural
        )
        return program_array is
        begin
            return write_instruction(sub, result_reg, left, right) & normalizer_fill & denormalizer_fill & write_instruction(nop) & write_instruction(nop) & write_instruction(nop);
        end sub;
        ------------------------------
        function add
        (
            result_reg, left, right : natural
        )
        return program_array is
        begin
            return write_instruction(add, result_reg, left, right) & normalizer_fill & denormalizer_fill & write_instruction(nop) & write_instruction(nop) & write_instruction(nop);
        end add;
        ------------------------------
        function multiply
        (
            result_reg, left, right : natural
        )
        return program_array is
        begin
            return write_instruction(mpy, result_reg, left, right) & normalizer_fill & write_instruction(nop) & write_instruction(nop) & write_instruction(nop) & write_instruction(nop);
        end multiply;
        ------------------------------

end package body float_assembler_pkg;
------------------------------------------------------------------------

