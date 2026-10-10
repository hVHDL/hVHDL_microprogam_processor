-- fixed point multiply-add on hVHDL_fixed_point's fixed_dsp :
--
--   mpy_add       dest <- a * b + c
--   mpy_sub       dest <- a * b - c
--   neg_mpy_add   dest <- -a * b + c
--   neg_mpy_sub   dest <- -a * b - c
--   a_add_b_mpy_c dest <- (a + b) * c
--   a_sub_b_mpy_c dest <- (a - b) * c
--   lp_filter     dest <- (a - b) * c + b
--   ext, ext_limit  dest <- a limited to +-b                 (mi_limit)
--   ext, ext_block  dest <- a, or 0 when a and b > 0 or a and b < 0 (mi_block)
--
-- The two ext functions are computed here and pass the fixed_dsp as a * 1.0, so they write at
-- the multiply-add's result stage (a math unit beside it ignores them).
--
-- with a, b, c the instruction's arguments 1, 2, 3. The sums and
-- differences of two arguments and -a are taken in fixed_dsp's pre-adder
-- and wrap to the data width, the result is bits g_radix + data width - 1
-- downto g_radix of the double width product, rounded to the nearest with
-- g_round_result (half a bit added in the post-adder), truncated without it.
-- acc, get_acc_and_zero and
-- check_and_saturate_acc work on a data width accumulator of their own.
architecture fixed_mult_add of execution_unit is

    use work.fixed_dsp_pkg.all;

    constant datawidth : natural := unit_in.data_read_out(unit_in.data_read_out'left).data'length;

    -- the request to fixed_dsp is registered here, the product is in P
    -- two clocks later, one more for each of the pre-adder and product
    -- registers
    constant result_stage : natural := fixed_point_result_stage(g_pre_add_register, g_product_register, g_data_ram_output_register)
        + g_read_delays + g_read_out_delays;

    signal dsp_in : fixed_dsp_in_record(
        a(datawidth-1 downto 0)
        ,d(datawidth-1 downto 0)
        ,b(datawidth-1 downto 0)
        ,c(2*datawidth-1 downto 0)
    ) := init_fixed_dsp_in(datawidth);

    signal dsp_out : fixed_dsp_out_record(result(2*datawidth-1 downto 0));

    signal accumulator : signed(datawidth-1 downto 0) := (others => '0');

    -- 1.0 at the radix: the own ext functions pass the dsp as value * one
    constant one : signed(datawidth-1 downto 0) := shift_left(to_signed(1, datawidth), g_radix);

    -- an ext instruction of this unit's own: limit, block
    function is_own_ext (instruction : std_logic_vector) return boolean is
    begin
        return decode(instruction) = ext and (get_arg3(instruction) = ext_limit or get_arg3(instruction) = ext_block);
    end is_own_ext;

begin

    u_fixed_dsp : entity work.fixed_dsp(rtl)
    generic map (g_pre_add_register => g_pre_add_register, g_product_register => g_product_register)
    port map (
        clock          => clock
        ,fixed_dsp_in  => dsp_in
        ,fixed_dsp_out => dsp_out
    );

    mpy_add_sub : process(clock) is
        variable arg1, arg2, arg3 : signed(datawidth-1 downto 0);
        variable zero : signed(datawidth-1 downto 0);

        -- c scaled to the product's g_radix, with g_round_result half a bit
        -- of the result added : subtracted from c when c is subtracted
        impure function scaled (c : signed; subtracted : boolean := false) return signed is
            constant half : signed(2*datawidth-1 downto 0) := shift_left(to_signed(boolean'pos(g_round_result), 2*datawidth), g_radix - 1);
        begin
            if subtracted then
                return shift_left(resize(c, 2*datawidth), g_radix) - half;
            end if;
            return shift_left(resize(c, 2*datawidth), g_radix) + half;
        end scaled;

    begin
        if rising_edge(clock) then
            init_mp_ram_read(unit_out.data_read_in);
            init_mp_write(unit_out.ram_write_in);
            init_fixed_dsp(dsp_in);

            ---------------
            if ram_read_is_ready(unit_in.instr_ram_read_out(0)) then
                CASE decode(get_ram_data(unit_in.instr_ram_read_out(0))) is
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

                        request_data_from_ram(unit_out.data_read_in(g_arg1_port)
                            , get_arg1(get_ram_data(unit_in.instr_ram_read_out(0))));

                        request_data_from_ram(unit_out.data_read_in(g_arg2_port)
                            , get_arg2(get_ram_data(unit_in.instr_ram_read_out(0))));

                        request_data_from_ram(unit_out.data_read_in(g_arg3_port)
                            , get_arg3(get_ram_data(unit_in.instr_ram_read_out(0))));

                    WHEN ext =>
                        if is_own_ext(get_ram_data(unit_in.instr_ram_read_out(0))) then
                            request_data_from_ram(unit_out.data_read_in(g_arg1_port)
                                , get_arg1(get_ram_data(unit_in.instr_ram_read_out(0))));
                            request_data_from_ram(unit_out.data_read_in(g_arg2_port)
                                , get_arg2(get_ram_data(unit_in.instr_ram_read_out(0))));
                        end if;

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------
            arg1 := signed(get_ram_data(unit_in.data_read_out(g_arg1_port)));
            arg2 := signed(get_ram_data(unit_in.data_read_out(g_arg2_port)));
            arg3 := signed(get_ram_data(unit_in.data_read_out(g_arg3_port)));
            zero := (others => '0');

            CASE decode(unit_in.instr_pipeline(data_read_latency(g_data_ram_output_register) + g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    fmac(dsp_in, a => arg1, d => zero, b => arg2, c => scaled(arg3));

                WHEN mpy_sub =>
                    fmac(dsp_in, a => arg1, d => zero, b => arg2, c => scaled(arg3, subtracted => true)
                        , post_subtract_with_1 => '1');

                WHEN neg_mpy_add =>
                    fmac(dsp_in, a => zero, d => arg1, b => arg2, c => scaled(arg3)
                        , pre_subtract_with_1 => '1');

                WHEN neg_mpy_sub =>
                    fmac(dsp_in, a => zero, d => arg1, b => arg2, c => scaled(arg3, subtracted => true)
                        , pre_subtract_with_1 => '1', post_subtract_with_1 => '1');

                WHEN a_add_b_mpy_c =>
                    fmac(dsp_in, a => arg1, d => arg2, b => arg3, c => scaled(zero));

                WHEN a_sub_b_mpy_c =>
                    fmac(dsp_in, a => arg1, d => arg2, b => arg3, c => scaled(zero)
                        , pre_subtract_with_1 => '1');

                WHEN lp_filter =>
                    fmac(dsp_in, a => arg1, d => arg2, b => arg3, c => scaled(arg2)
                        , pre_subtract_with_1 => '1');

                WHEN acc | get_acc_and_zero =>
                    accumulator <= accumulator + arg3;

                WHEN ext =>
                    -- the own ext functions, through the dsp as value * 1.0
                    if get_arg3(unit_in.instr_pipeline(data_read_latency(g_data_ram_output_register) + g_read_delays + g_read_out_delays)) = ext_limit then
                        if arg1 > arg2 then
                            fmac(dsp_in, a => arg2, d => zero, b => one, c => scaled(zero));
                        elsif arg1 < -arg2 then
                            fmac(dsp_in, a => -arg2, d => zero, b => one, c => scaled(zero));
                        else
                            fmac(dsp_in, a => arg1, d => zero, b => one, c => scaled(zero));
                        end if;
                    elsif get_arg3(unit_in.instr_pipeline(data_read_latency(g_data_ram_output_register) + g_read_delays + g_read_out_delays)) = ext_block then
                        if (arg1 > 0 and arg2 > 0) or (arg1 < 0 and arg2 < 0) then
                            fmac(dsp_in, a => zero, d => zero, b => one, c => scaled(zero));
                        else
                            fmac(dsp_in, a => arg1, d => zero, b => one, c => scaled(zero));
                        end if;
                    end if;

                WHEN check_and_saturate_acc =>

                    if arg3 < 0
                    then
                        if accumulator <= arg2
                        then
                            accumulator <= arg2;
                        end if;
                    else
                        if accumulator >= arg2
                        then
                            accumulator <= arg2;
                        end if;
                    end if;

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(unit_in.instr_pipeline(result_stage)) is
                WHEN mpy_add
                    | neg_mpy_add
                    | neg_mpy_sub
                    | mpy_sub
                    | a_add_b_mpy_c
                    | a_sub_b_mpy_c
                    | lp_filter =>

                    write_data_to_ram(unit_out.ram_write_in
                    , get_dest(unit_in.instr_pipeline(result_stage))
                    , std_logic_vector(dsp_out.result(g_radix + datawidth - 1 downto g_radix)));

                WHEN ext =>
                    if is_own_ext(unit_in.instr_pipeline(result_stage)) then
                        write_data_to_ram(unit_out.ram_write_in
                        , get_dest(unit_in.instr_pipeline(result_stage))
                        , std_logic_vector(dsp_out.result(g_radix + datawidth - 1 downto g_radix)));
                    end if;

                WHEN get_acc_and_zero =>

                    write_data_to_ram(unit_out.ram_write_in
                    , get_dest(unit_in.instr_pipeline(result_stage))
                    , std_logic_vector(accumulator));

                    accumulator <= (others => '0');

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end fixed_mult_add;
