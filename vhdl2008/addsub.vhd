
architecture add_sub_mpy of instruction is

    constant g_radix : natural := radix;

    constant datawidth : natural := instruction_in.data_read_out(instruction_in.data_read_out'left).data'length;
    signal a, b, d     : signed(datawidth-1 downto 0);
    -- c is added directly into the multiplier's output width now, so it
    -- must already be pre-shifted/resized to that width (see the c <=
    -- assignments below)
    signal c           : signed(2*datawidth-1 downto 0);
    signal dsp_result  : signed(2*datawidth-1 downto 0);

    signal mac_mpy     : signed(2*datawidth-1 downto 0);
    signal accumulator : mac_mpy'subtype := (others => '0');

    signal accumulate        : std_logic := '0';-- 0=p <= p + (a*b)
    signal pre_subtract      : std_logic := '0';-- 0=a+d
    signal post_subtract     : std_logic := '0';-- 0=mpy_out+d, 1 => mpy_out-d
    signal invert_result     : std_logic := '0'; -- 1 => negate multiplier result
    signal buf_accumulate    : std_logic := '0';
    signal reset_accumulator : std_logic := '0';

    signal ready_with_1 : std_logic := '0';

begin

    u_fixed_dsp : entity work.fixed_dsp
    port map( clock => clock
    ,fixed_dsp_in.a => a
    ,fixed_dsp_in.d => d
    ,fixed_dsp_in.b => b
    ,fixed_dsp_in.c => c

    ,fixed_dsp_in.request_with_1       => '1'
    ,fixed_dsp_in.accumulate_with_1    => accumulate
    ,fixed_dsp_in.pre_subtract_with_1  => pre_subtract
    ,fixed_dsp_in.post_subtract_with_1 => post_subtract
    ,fixed_dsp_in.invert_result_with_1 => invert_result

    ,fixed_dsp_in.reset_accumulator_with_1 => reset_accumulator

    ,fixed_dsp_out.ready_with_1 => ready_with_1
    ,fixed_dsp_out.result       => dsp_result
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
                    c <= shift_left(resize(signed(get_ram_data(instruction_in.data_read_out(arg3_mem))), 2*datawidth), g_radix);

                WHEN neg_mpy_add =>
                    accumulate    <= '0';
                    pre_subtract  <= '1';
                    post_subtract <= '0';
                    invert_result <= '0';

                    a <= (others => '0');
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= shift_left(resize(signed(get_ram_data(instruction_in.data_read_out(arg3_mem))), 2*datawidth), g_radix);

                WHEN neg_mpy_sub =>
                    accumulate    <= '0';
                    pre_subtract  <= '0';
                    post_subtract <= '1';
                    invert_result <= '0';

                    a <= (others => '0');
                    d <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= shift_left(resize(signed(get_ram_data(instruction_in.data_read_out(arg3_mem))), 2*datawidth), g_radix);

                WHEN mpy_sub =>
                    accumulate    <= '0';
                    pre_subtract  <= '0';
                    post_subtract <= '1';
                    invert_result <= '0';

                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    d <= (others => '0');
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= shift_left(resize(signed(get_ram_data(instruction_in.data_read_out(arg3_mem))), 2*datawidth), g_radix);

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
                    c <= shift_left(resize(signed(get_ram_data(instruction_in.data_read_out(arg2_mem))), 2*datawidth), g_radix);

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
