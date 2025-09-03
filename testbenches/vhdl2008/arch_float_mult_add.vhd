
architecture float_mult_add of instruction is

    use work.real_to_fixed_pkg.all;

    constant datawidth : natural := instruction_in.data_read_out(instruction_in.data_read_out'left).data'length;
    signal a, b, c , cbuf : signed(datawidth-1 downto 0);
    signal mpy_res        : signed(2*datawidth-1 downto 0);
    signal mpy_res2       : signed(2*datawidth-1 downto 0);

    signal accumulator : signed(datawidth-1 downto 0) := (others => '0');

begin

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
            mpy_res2 <= a * b;
            cbuf     <= c;
            mpy_res  <= mpy_res2 + shift_left(resize(cbuf , mpy_res'length), radix) ;
            ---------------

            CASE decode(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay+g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    a <= signed(get_ram_data(instruction_in.data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(instruction_in.data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN neg_mpy_add =>
                    a <= signed( not get_ram_data(instruction_in.data_read_out(arg1_mem)));
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

end float_mult_add;
----
--
