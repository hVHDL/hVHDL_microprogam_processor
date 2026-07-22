    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

package instruction_pkg is

    type instruction_in_record is record
        data_read_out      : ram_read_out_array  ;
        instr_ram_read_out : ram_read_out_array ;
        instr_pipeline     : instruction_pipeline_array ;
    end record;

    type instruction_out_record is record
        data_read_in : ram_read_in_array  ;
        ram_write_in : ram_write_in_record ;
    end record;

end package instruction_pkg;
----------------------------------
----------------------------------
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

LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.instruction_pkg.all;

entity instruction is
    generic(
        arg1_mem             : natural := 0
        ;arg2_mem            : natural := 1
        ;arg3_mem            : natural := 2
        ;radix               : natural := 14
        ;g_read_delays       : natural := 0
        ;g_read_out_delays   : natural := 0
        ;g_instruction_delay : natural := 9
        ;g_option            : string  := "hfloat"
        ------ instruction encodings -------
        ;g_mpy_add       : natural := 0
        ;g_mpy_sub       : natural := 1
        ;g_neg_mpy_add   : natural := 2
        ;g_neg_mpy_sub   : natural := 3
        ;g_a_add_b_mpy_c : natural := 4
        ;g_a_sub_b_mpy_c : natural := 5
        ;g_lp_filter     : natural := 6
       );
    port(
        clock : in std_logic
        ;instruction_in : in instruction_in_record
        ;instruction_out : out instruction_out_record
    );
end;

architecture add_sub_mpy of instruction is

    constant g_radix : natural := radix;

    constant datawidth : natural := instruction_in.data_read_out(instruction_in.data_read_out'left).data'length;
    signal a, b, c, d  : signed(datawidth-1 downto 0);
    signal dsp_result  : signed(2*datawidth-1 downto 0);

    signal mac_mpy     : signed(2*datawidth-1 downto 0);
    signal accumulator : mac_mpy'subtype := (others => '0');

    signal accumulate        : std_logic := '0';-- 0=p <= p + (a*b)
    signal pre_subtract      : std_logic := '0';-- 0=a+d
    signal post_subtract     : std_logic := '0';-- 0=mpy_out+d, 1 => mpy_out-d
    signal invert_result     : std_logic := '0'; -- 1 => negate multiplier result
    signal buf_accumulate    : std_logic := '0';
    signal reset_accumulator : std_logic := '0';

begin

    u_fixed_dsp : entity work.fixed_dsp
    generic map(g_radix => g_radix)
    port map( clock => clock
    ,a => a
    ,d => d
    ,b => b
    ,c => c

    ,accumulate_with_1    => accumulate
    ,pre_subtract_with_1  => pre_subtract
    ,post_subtract_with_1 => post_subtract
    ,invert_result_with_1 => invert_result

    ,reset_accumulator_with_1 => reset_accumulator

    ,result => dsp_result
    );


    multiply_accumulate : process(clock) is
    begin
        if rising_edge(clock) then
            mac_mpy        <= resize(a*b, mac_mpy'length);
            buf_accumulate <= accumulate;

            if buf_accumulate = '1' then
                accumulator <= accumulator + mac_mpy;
            end if;
            if reset_accumulator= '1' then
                accumulator <= (others => '0');
            end if;
        end if;
    end process;

    mpy_add_sub : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(instruction_out.data_read_in);
            init_mp_write(instruction_out.ram_write_in);

            ---------------
            if ram_read_is_ready(instruction_in.instr_ram_read_out(0)) then
                CASE decode(get_ram_data(instruction_in.instr_ram_read_out(0))) is
                    WHEN mpy_add 
                        | neg_mpy_add 
                        | neg_mpy_sub 
                        | mpy_sub 
                        | a_add_b_mpy_c 
                        | a_sub_b_mpy_c 
                        | lp_filter 
                        | acc 
                        | get_acc_and_zero 
                        | check_and_saturate_acc 
                        | mpy_acc
                        =>

                        request_data_from_ram(instruction_out.data_read_in(arg1_mem)
                            , get_arg1(get_ram_data(instruction_in.instr_ram_read_out(0))));

                        request_data_from_ram(instruction_out.data_read_in(arg2_mem)
                            , get_arg2(get_ram_data(instruction_in.instr_ram_read_out(0))));

                        request_data_from_ram(instruction_out.data_read_in(arg3_mem)
                            , get_arg3(get_ram_data(instruction_in.instr_ram_read_out(0))));

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------

            accumulate    <= '0';
            CASE decode(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay+g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    accumulate    <= '0';
                    pre_subtract  <= '0';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= (others => '0');
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN neg_mpy_add =>
                    accumulate    <= '0';
                    pre_subtract  <= '1';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= (others => '0');
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN neg_mpy_sub =>
                    accumulate    <= '0';
                    pre_subtract  <= '0';
                    post_subtract <= '1';
                    invert_result <= '0';

                    a <= (others => '0');
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN mpy_sub =>
                    accumulate    <= '0';
                    pre_subtract  <= '0';
                    post_subtract <= '1';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= (others => '0');
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN a_add_b_mpy_c =>
                    accumulate    <= '0';
                    pre_subtract  <= '0';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN a_sub_b_mpy_c =>
                    accumulate    <= '0';
                    pre_subtract  <= '1';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN lp_filter =>
                    accumulate    <= '1';
                    pre_subtract  <= '1';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));

                WHEN mpy_acc | get_acc_and_zero =>
                    accumulate    <= '1';
                    pre_subtract  <= '0';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= (others => '0');
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= (others => '0');

                WHEN others => -- do nothing
            end CASE;
            ---------------
            reset_accumulator <= '0';
            CASE decode(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays)) is
                WHEN mpy_add 
                    | neg_mpy_add   
                    | neg_mpy_sub   
                    | mpy_sub
                    | a_add_b_mpy_c 
                    | a_sub_b_mpy_c 
                    | lp_filter =>

                    write_data_to_ram(instruction_out.ram_write_in 
                    , get_dest(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays))
                    , std_logic_vector(dsp_result(radix+instruction_in.data_read_out(instruction_in.data_read_out'left).data'length-1 downto radix)));

                WHEN get_acc_and_zero =>

                    reset_accumulator <= '1';
                    write_data_to_ram(instruction_out.ram_write_in
                    , get_dest(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays))
                    , std_logic_vector(accumulator(radix+instruction_in.data_read_out(instruction_in.data_read_out'left).data'length-1 downto radix)));

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
----
