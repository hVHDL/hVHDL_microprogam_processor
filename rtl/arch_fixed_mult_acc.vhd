LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

-- fixed point multiply-add on hVHDL_fixed_point's fixed_dsp with a double
-- width accumulator :
--
--   mpy_add          dest <- a * b + c
--   mpy_sub          dest <- a * b - c
--   neg_mpy_add      dest <- -a * b + c
--   neg_mpy_sub      dest <- -a * b - c
--   a_add_b_mpy_c    dest <- (a + b) * c
--   a_sub_b_mpy_c    dest <- (a - b) * c
--   lp_filter        dest <- (a - b) * c + b
--   mpy_acc          accumulator <- accumulator + a * b
--   acc              accumulator <- accumulator + c
--   get_acc_and_zero dest <- accumulator + c, accumulator <- 0
--
-- with a, b, c the instruction's arguments 1, 2, 3. The sums and
-- differences of two arguments and -a are taken in fixed_dsp's pre-adder
-- and wrap to the data width, c is added at the product's g_radix and a
-- result is bits g_radix + data width - 1 downto g_radix of the double width
-- product or accumulator. Every command goes through the one fixed_dsp,
-- the accumulator adds its results.
architecture fixed_mult_acc of execution_unit is

    use work.fixed_dsp_pkg.all;

    constant datawidth : natural := unit_in.data_read_out(unit_in.data_read_out'left).data'length;

    -- the request to fixed_dsp is registered here, the product is in P
    -- two clocks later, one more for each of the pre-adder and product
    -- registers
    constant result_stage : natural := work.dual_port_ram_pkg.read_pipeline_delay + 3
        + boolean'pos(g_pre_add_register) + boolean'pos(g_product_register)
        + g_read_delays + g_read_out_delays;

    signal dsp_in : fixed_dsp_in_record(
        a(datawidth-1 downto 0)
        ,d(datawidth-1 downto 0)
        ,b(datawidth-1 downto 0)
        ,c(2*datawidth-1 downto 0)
    ) := init_fixed_dsp_in(datawidth);

    signal dsp_out : fixed_dsp_out_record(result(2*datawidth-1 downto 0));

    signal accumulator : signed(2*datawidth-1 downto 0) := (others => '0');

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
        variable sum  : signed(2*datawidth-1 downto 0);

        -- c scaled to the product's g_radix
        impure function scaled (c : signed) return signed is
        begin
            return shift_left(resize(c, 2*datawidth), g_radix);
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
                        | mpy_acc
                        =>

                        request_data_from_ram(unit_out.data_read_in(g_arg1_port)
                            , get_arg1(get_ram_data(unit_in.instr_ram_read_out(0))));

                        request_data_from_ram(unit_out.data_read_in(g_arg2_port)
                            , get_arg2(get_ram_data(unit_in.instr_ram_read_out(0))));

                        request_data_from_ram(unit_out.data_read_in(g_arg3_port)
                            , get_arg3(get_ram_data(unit_in.instr_ram_read_out(0))));

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------
            arg1 := signed(get_ram_data(unit_in.data_read_out(g_arg1_port)));
            arg2 := signed(get_ram_data(unit_in.data_read_out(g_arg2_port)));
            arg3 := signed(get_ram_data(unit_in.data_read_out(g_arg3_port)));
            zero := (others => '0');

            CASE decode(unit_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    fmac(dsp_in, a => arg1, d => zero, b => arg2, c => scaled(arg3));

                WHEN mpy_sub =>
                    fmac(dsp_in, a => arg1, d => zero, b => arg2, c => scaled(arg3)
                        , post_subtract_with_1 => '1');

                WHEN neg_mpy_add =>
                    fmac(dsp_in, a => zero, d => arg1, b => arg2, c => scaled(arg3)
                        , pre_subtract_with_1 => '1');

                WHEN neg_mpy_sub =>
                    fmac(dsp_in, a => zero, d => arg1, b => arg2, c => scaled(arg3)
                        , pre_subtract_with_1 => '1', post_subtract_with_1 => '1');

                WHEN a_add_b_mpy_c =>
                    fmac(dsp_in, a => arg1, d => arg2, b => arg3, c => scaled(zero));

                WHEN a_sub_b_mpy_c =>
                    fmac(dsp_in, a => arg1, d => arg2, b => arg3, c => scaled(zero)
                        , pre_subtract_with_1 => '1');

                WHEN lp_filter =>
                    fmac(dsp_in, a => arg1, d => arg2, b => arg3, c => scaled(arg2)
                        , pre_subtract_with_1 => '1');

                WHEN mpy_acc =>
                    fmac(dsp_in, a => arg1, d => zero, b => arg2, c => scaled(zero));

                WHEN acc | get_acc_and_zero =>
                    fmac(dsp_in, a => zero, d => zero, b => zero, c => scaled(arg3));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            sum := accumulator + dsp_out.result;

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

                WHEN mpy_acc | acc =>
                    accumulator <= sum;

                WHEN get_acc_and_zero =>
                    write_data_to_ram(unit_out.ram_write_in
                    , get_dest(unit_in.instr_pipeline(result_stage))
                    , std_logic_vector(sum(g_radix + datawidth - 1 downto g_radix)));

                    accumulator <= (others => '0');

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end fixed_mult_acc;
