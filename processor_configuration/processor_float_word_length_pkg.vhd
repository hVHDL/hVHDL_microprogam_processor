library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;


-- float processor word length definitions
package float_word_length_pkg is

    constant mantissa_bits : integer := 20;
    constant exponent_bits : integer := 8;

end package float_word_length_pkg;
