architecture rtl of fixed_dsp is

    signal pre  : signed(a'length-1 downto 0);
    signal mult : signed(a'length + b'length-1 downto 0);

    signal c_buf : mult'subtype;

    signal P : result'subtype := (others => '0');

    signal buf_accumulate    : std_logic;-- 0=p <= p + (a*b)
    signal buf_pre_subtract  : std_logic;-- 0=a+d
    signal buf_post_subtract : std_logic;-- 0=mpy_out+d, 1 => mpy_out-d
    signal buf_invert_result : std_logic;-- 1 => negate multiplier result

    signal buf_reset_accumulator_with_1 : std_logic;

begin

    -- output 
    result <= P;

    -- Pre-adder
    pre <= a + d when pre_subtract_with_1 = '0'
     else  a - d;

    process(clock)
    begin
        if rising_edge(clock) then

            --p1
            -- Resize to accumulator width
            mult  <= pre * B;
            c_buf <= shift_left(resize(c, c_buf'length), g_radix);

            buf_accumulate    <= accumulate_with_1   ;
            buf_pre_subtract  <= pre_subtract_with_1 ;
            buf_post_subtract <= post_subtract_with_1;
            buf_invert_result <= invert_result_with_1;
            buf_reset_accumulator_with_1 <= reset_accumulator_with_1;

            --p2
            if buf_invert_result = '1' then
                if buf_post_subtract = '0' then
                    P <= -(mult + c_buf);
                else
                    P <= -(mult - c_buf);
                end if;
            else
                if buf_post_subtract = '0' then
                    P <= mult + c_buf;
                else
                    P <= mult - c_buf;
                end if;
            end if;
            --

            if buf_accumulate = '1' then
                if buf_post_subtract = '1' then
                    P <= P - mult;
                else
                    P <= P + mult;
                end if;
            end if;

            if buf_reset_accumulator_with_1 = '1' then
                P <= (others => '0');
            end if;

        end if;
    end process;

end rtl;

----------------------------------

