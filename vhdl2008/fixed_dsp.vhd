LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

entity fixed_dsp is
    generic(g_radix : natural);
    port(
        clock : in std_logic := '0'
        ;a    : in signed
        ;d    : in signed
        ;b    : in signed
        ;c    : in signed

        ;accumulate_with_1    : in std_logic -- 0=p <= p + (a*b)
        ;pre_subtract_with_1  : in std_logic -- 0=a+d
        ;post_subtract_with_1 : in std_logic -- 0=mpy_out+d, 1 => mpy_out-d
        ;invert_result_with_1 : in std_logic -- 1 => negate multiplier result
        ;reset_accumulator_with_1 : in std_logic

        ;result : out signed
    );
end entity;
