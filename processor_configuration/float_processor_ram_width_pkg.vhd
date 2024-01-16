
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    -- used in simple processor simulation
    use work.float_word_length_pkg.mantissa_bits;
    use work.float_word_length_pkg.exponent_bits;

package ram_configuration_pkg is

    -- make visible when using ram_read
    constant ram_bit_width : natural := mantissa_bits+exponent_bits+1;
    constant ram_depth     : natural := 2**9;

    subtype address_integer is natural range 0 to ram_depth-1;
    subtype t_ram_data      is std_logic_vector(ram_bit_width-1 downto 0);

    type ram_array is array (integer range 0 to ram_depth-1) of t_ram_data;

end package ram_configuration_pkg;
------------------------------------------------------------------------
