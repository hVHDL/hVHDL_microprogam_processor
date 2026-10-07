LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

-- fixed point math on hVHDL_fixed_point's blocks, the ext command's
-- functions :
--
--   ext_div, mi_div(dest, a, b) : dest <- a / b at the radix, by
--       lut_divider with a 512 x 18 bit reciprocal table ; a quotient too
--       large for the word wraps, division by zero is not handled
--   ext_sqrt, mi_sqrt(dest, a) : dest <- sqrt(a) at the radix, by
--       full_range_sqrt with a 512 x 18 bit table at radix 17 ; a is
--       taken as unsigned, a negative one is not handled
--   ext_sin, ext_cos, mi_sin(dest, a), mi_cos(dest, a) : dest <-
--       sin(2 pi a), cos(2 pi a) at the radix, a in turns : the 16 bits
--       under the radix are the angle, sine_calculator's 16 bit quarter
--       wave table interpolated on a fixed_dsp gives 16 bits at radix 15,
--       cos is the sine a quarter turn on. The radix must be 16 or more
--
-- with a, b the instruction's arguments 1 and 2. Both have the same
-- structure (a normalising shifter, an interpolated lookup on a fixed_dsp,
-- a multiply on a second one, an output shifter) and so the same latency,
-- lut_divider_latency() ; the sine is shorter and waits in a delay line.
-- A result is written in
-- execution_unit_pkg's fixed_math_result_stage(), the caller's instruction
-- pipeline must be that long. The commands of the other units are ignored,
-- this unit shares microprogram_core with them through merge_units().
architecture fixed_math of execution_unit is

    use work.lut_divider_pkg.all;
    use work.full_range_sqrt_pkg.all;
    use work.fixed_dsp_pkg.all;
    use work.lut_sine_pkg.angle_word_length;
    use work.sine_calculator_pkg.all;

    constant datawidth : natural := unit_in.data_read_out(unit_in.data_read_out'left).data'length;

    -- the operands arrive, and are registered into the divider's request
    constant operand_stage : natural := data_read_latency(g_data_ram_output_register)
        + g_read_delays + g_read_out_delays;
    -- the quotient is ready and written
    constant result_stage : natural := fixed_math_result_stage(g_pre_add_register, g_product_register, g_data_ram_output_register,
        g_divider_shifter_stages, g_math_ram_output_register, g_math_dsp_request_register)
        + g_read_delays + g_read_out_delays;

    signal divider_in : lut_divider_in_record(
        numerator(datawidth-1 downto 0)
        ,denominator(datawidth-1 downto 0)
    ) := (numerator => (others => '0'), denominator => (others => '0'), request_with_1 => '0');

    signal divider_out : lut_divider_out_record(quotient(datawidth-1 downto 0));

    signal sqrt_in : full_range_sqrt_in_record(radicand(datawidth-1 downto 0))
        := (radicand => (others => '0'), request_with_1 => '0');
    signal sqrt_out : full_range_sqrt_out_record(root(datawidth-1 downto 0));

    function is_division (instruction : std_logic_vector) return boolean is
    begin
        return decode(instruction) = ext and get_arg3(instruction) = ext_div;
    end is_division;

    -- the sine waits for the divider's latency
    constant sine_delay : natural := lut_divider_latency(g_pre_add_register, g_product_register, g_divider_shifter_stages,
            g_math_ram_output_register, g_math_dsp_request_register)
        - sine_calculator_latency(g_pre_add_register, g_product_register,
            g_math_ram_output_register, g_math_dsp_request_register);

    signal sine_in  : sine_calculator_in_record := (angle => (others => '0'), request_with_1 => '0');
    signal sine_out : sine_calculator_out_record;
    -- the sine calculator's fixed_dsp, 18 bits
    signal sine_dsp_in : fixed_dsp_in_record(a(17 downto 0), d(17 downto 0), b(17 downto 0), c(35 downto 0))
        := init_fixed_dsp_in(18);
    signal sine_dsp_out : fixed_dsp_out_record(result(35 downto 0));

    type sine_array is array (natural range <>) of signed(angle_word_length-1 downto 0);
    -- sine_history(k) holds the sine k clocks ago
    signal sine_history  : sine_array(1 to sine_delay) := (others => (others => '0'));
    signal ready_history : std_logic_vector(1 to sine_delay) := (others => '0');

    function is_sine (instruction : std_logic_vector) return boolean is
    begin
        return decode(instruction) = ext and (get_arg3(instruction) = ext_sin or get_arg3(instruction) = ext_cos);
    end is_sine;

    -- the angle, the 16 bits under the radix, a quarter turn on for cos
    function angle_of (instruction, word : std_logic_vector) return unsigned is
        -- descending whatever the caller's range : Quartus and Efinity
        -- reject a descending slice of an unconstrained parameter
        constant data   : std_logic_vector(word'length-1 downto 0) := word;
        variable retval : unsigned(angle_word_length-1 downto 0);
    begin
        retval := unsigned(data(g_radix-1 downto g_radix-angle_word_length));
        if get_arg3(instruction) = ext_cos then
            retval := retval + 2**(angle_word_length-2);
        end if;
        return retval;
    end angle_of;

    function is_square_root (instruction : std_logic_vector) return boolean is
    begin
        return decode(instruction) = ext and get_arg3(instruction) = ext_sqrt;
    end is_square_root;

begin

    assert g_radix >= angle_word_length
        report "fixed_math's sine takes the 16 bits under the radix, the radix must be 16 or more"
        severity failure;

    assert result_stage <= unit_in.instr_pipeline'high
        report "fixed_math writes its result in pipeline stage " & integer'image(result_stage)
            & ", the instruction pipeline ends at " & integer'image(unit_in.instr_pipeline'high)
        severity failure;

    u_lut_divider : entity work.lut_divider
    generic map (
        g_quotient_radix     => g_radix
        ,g_index_width       => 9
        ,g_table_word_length => 18
        ,g_table_radix       => 16
        ,g_x_frac_width      => 18
        ,g_pre_add_register  => g_pre_add_register
        ,g_product_register  => g_product_register
        ,g_shifter_stages    => g_divider_shifter_stages
        ,g_ram_output_register  => g_math_ram_output_register
        ,g_dsp_request_register => g_math_dsp_request_register
    )
    port map (
        clock            => clock
        ,lut_divider_in  => divider_in
        ,lut_divider_out => divider_out
    );

    u_full_range_sqrt : entity work.full_range_sqrt
    generic map (
        g_radix              => g_radix
        ,g_index_width       => 9
        ,g_table_word_length => 18
        ,g_table_radix       => 17
        ,g_x_frac_width      => 18
        ,g_pre_add_register  => g_pre_add_register
        ,g_product_register  => g_product_register
        ,g_shifter_stages    => g_divider_shifter_stages
        ,g_ram_output_register  => g_math_ram_output_register
        ,g_dsp_request_register => g_math_dsp_request_register
    )
    port map (
        clock                => clock
        ,full_range_sqrt_in  => sqrt_in
        ,full_range_sqrt_out => sqrt_out
    );

    u_sine_calculator : entity work.sine_calculator
    generic map (
        g_ram_output_register   => g_math_ram_output_register
        ,g_dsp_request_register => g_math_dsp_request_register
    )
    port map (
        clock                => clock
        ,sine_calculator_in  => sine_in
        ,sine_calculator_out => sine_out
        ,fixed_dsp_in        => sine_dsp_in
        ,fixed_dsp_out       => sine_dsp_out
    );

    u_sine_dsp : entity work.fixed_dsp(rtl)
    generic map (g_pre_add_register => g_pre_add_register, g_product_register => g_product_register)
    port map (
        clock          => clock
        ,fixed_dsp_in  => sine_dsp_in
        ,fixed_dsp_out => sine_dsp_out
    );

    calculate : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(unit_out.data_read_in);
            init_mp_write(unit_out.ram_write_in);
            divider_in.request_with_1 <= '0';
            sqrt_in.request_with_1    <= '0';
            sine_in.request_with_1    <= '0';
            sine_history  <= sine_out.sine & sine_history(1 to sine_delay-1);
            ready_history <= sine_out.ready_with_1 & ready_history(1 to sine_delay-1);

            -- the operands' reads, when the instruction leaves the program ram
            if ram_read_is_ready(unit_in.instr_ram_read_out(0)) then
                if is_division(get_ram_data(unit_in.instr_ram_read_out(0)))
                    or is_square_root(get_ram_data(unit_in.instr_ram_read_out(0)))
                    or is_sine(get_ram_data(unit_in.instr_ram_read_out(0)))
                then
                    request_data_from_ram(unit_out.data_read_in(g_arg1_port)
                        , get_arg1(get_ram_data(unit_in.instr_ram_read_out(0))));
                end if;
                if is_division(get_ram_data(unit_in.instr_ram_read_out(0))) then
                    request_data_from_ram(unit_out.data_read_in(g_arg2_port)
                        , get_arg2(get_ram_data(unit_in.instr_ram_read_out(0))));
                end if;
            end if;

            if is_division(unit_in.instr_pipeline(operand_stage)) then
                divider_in <= (
                    numerator       => signed(get_ram_data(unit_in.data_read_out(g_arg1_port)))
                    ,denominator    => signed(get_ram_data(unit_in.data_read_out(g_arg2_port)))
                    ,request_with_1 => '1');
            end if;
            if is_sine(unit_in.instr_pipeline(operand_stage)) then
                sine_in <= (
                    angle           => angle_of(unit_in.instr_pipeline(operand_stage)
                                        , get_ram_data(unit_in.data_read_out(g_arg1_port)))
                    ,request_with_1 => '1');
            end if;
            if is_square_root(unit_in.instr_pipeline(operand_stage)) then
                sqrt_in <= (
                    radicand        => unsigned(get_ram_data(unit_in.data_read_out(g_arg1_port)))
                    ,request_with_1 => '1');
            end if;

            if is_division(unit_in.instr_pipeline(result_stage)) then
                assert divider_out.ready_with_1 = '1'
                    report "fixed_math : no quotient from lut_divider in the result stage"
                    severity failure;
                write_data_to_ram(unit_out.ram_write_in
                    , get_dest(unit_in.instr_pipeline(result_stage))
                    , std_logic_vector(divider_out.quotient));
            end if;
            if is_square_root(unit_in.instr_pipeline(result_stage)) then
                assert sqrt_out.ready_with_1 = '1'
                    report "fixed_math : no root from full_range_sqrt in the result stage"
                    severity failure;
                write_data_to_ram(unit_out.ram_write_in
                    , get_dest(unit_in.instr_pipeline(result_stage))
                    , std_logic_vector(sqrt_out.root));
            end if;
            if is_sine(unit_in.instr_pipeline(result_stage)) then
                assert ready_history(sine_delay) = '1'
                    report "fixed_math : no sine from sine_calculator in the result stage"
                    severity failure;
                write_data_to_ram(unit_out.ram_write_in
                    , get_dest(unit_in.instr_pipeline(result_stage))
                    , std_logic_vector(shift_left(resize(sine_history(sine_delay), datawidth), g_radix - 15)));
            end if;
        end if;
    end process calculate;

end fixed_math;
