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
        clock : in std_logic           := '0'
        ;a    : in signed(31 downto 0) := (others => '0')
        ;d    : in signed(31 downto 0) := (others => '0')
        ;b    : in signed(31 downto 0) := (others => '0')
        ;c    : in signed(31 downto 0) := (others => '0')

        ;accumulate    : in std_logic -- 0=p <= p + (a*b)
        ;pre_subtract  : in std_logic -- 0=a+d
        ;post_subtract : in std_logic -- 0=mpy_out+d, 1 => mpy_out-d
        ;invert_mult   : in std_logic -- 1 => negate multiplier result

        ;result : out signed(63 downto 0)
    );
end entity;

architecture rtl of fixed_dsp is
    signal cbuf    : signed(a'length-1 downto 0);
    signal mpy_res : signed(2*cbuf'length-1 downto 0);

    signal pre  : signed(a'length-1 downto 0);
    signal mult : signed(a'length + b'length-1 downto 0);
    signal m48  : signed(a'length + b'length-1 downto 0);

    signal c_buf : m48'subtype;

    alias radix is g_radix;
    alias P is result;

    signal buf_accumulate    : std_logic;-- 0=p <= p + (a*b)
    signal buf_pre_subtract  : std_logic;-- 0=a+d
    signal buf_post_subtract : std_logic;-- 0=mpy_out+d, 1 => mpy_out-d
    signal buf_invert_mult   : std_logic;-- 1 => negate multiplier result


begin

    -- Pre-adder
    pre <= a + d when pre_subtract = '0'
           else a - d;

    -- Multiplier
    mult <= pre * B;

    process(clock)
    begin
        if rising_edge(clock) then

            --p1
            -- Resize to accumulator width
            m48 <= resize(mult, P'length);
            c_buf <= shift_left(resize(c, c_buf'length), radix);

            --p2
            if invert_mult = '1' then
                if post_subtract = '0' then
                    P <= c_buf - m48;
                else
                    P <= -(c_buf + m48);
                end if;
            else
                if post_subtract = '0' then
                    P <= c_buf + m48;
                else
                    P <= c_buf - m48;
                end if;
            end if;
            --

            -- if accumulate = '1' then
            --     P <= P + m48;
            -- end if;

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

    use work.real_to_fixed_pkg.all;

    constant datawidth : natural := instruction_in.data_read_out(instruction_in.data_read_out'left).data'length;
    signal a, b, c , cbuf : signed(datawidth-1 downto 0);
    signal mpy_res        : signed(2*datawidth-1 downto 0);

    signal accumulator : signed(datawidth-1 downto 0) := (others => '0');

    signal dsp_op : std_logic_vector(3 downto 0) := (others => '0');
    alias accumulate    is dsp_op(0); -- 0=p <= p + (a*b)
    alias pre_subtract  is dsp_op(1); -- 0=a+d
    alias post_subtract is dsp_op(2); -- 0=mpy_out+d, 1 => mpy_out-d
    alias invert_mult   is dsp_op(3); -- 1 => negate multiplier result

begin

    u_fixed_dsp : entity work.fixed_dsp
    generic map(g_radix => radix)
    port map( clock => clock
    ,a => a
    ,b => b
    ,c => c

    ,accumulate    => accumulate   
    ,pre_subtract  => pre_subtract 
    ,post_subtract => post_subtract
    ,invert_mult   => invert_mult  

    ,result => mpy_res
    );

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

            CASE decode(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay+g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN neg_mpy_add =>
                    a <= signed(not get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN neg_mpy_sub =>
                    a <= signed( not get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed( not get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN mpy_sub =>
                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed( not get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN a_add_b_mpy_c =>
                    a <=   signed(get_ram_data(instruction_in.data_read_out(arg1_mem)))
                         + signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN a_sub_b_mpy_c =>
                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)))
                         + signed( not get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN lp_filter =>
                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)))
                         + signed( not get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));

                WHEN acc | get_acc_and_zero =>
                    accumulator <= accumulator + signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN check_and_saturate_acc =>

                    if signed(get_ram_data(instruction_in.data_read_out(arg3_mem))) < 0
                    then
                        if accumulator <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)))
                        then
                            accumulator <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                        end if;
                    else
                        if accumulator >= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)))
                        then
                            accumulator <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                        end if;
                    end if;

                WHEN others => -- do nothing
            end CASE;
            ---------------
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
                    , std_logic_vector(mpy_res(radix+instruction_in.data_read_out(instruction_in.data_read_out'left).data'length-1 downto radix)));

                WHEN get_acc_and_zero =>

                    write_data_to_ram(instruction_out.ram_write_in
                    , get_dest(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays))
                    , std_logic_vector(accumulator));

                    accumulator <= (others => '0');

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
----
