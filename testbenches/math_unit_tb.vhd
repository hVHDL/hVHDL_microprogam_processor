LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.all;
    use work.microprogram_assembler_pkg.all;
    use work.lut_reciprocal_pkg.all;
    use work.lut_divider_pkg.all;
    use work.lut_sqrt_pkg.all;
    use work.full_range_sqrt_pkg.all;
    use work.lut_sine_pkg.all;

-- fixed_mult_add and fixed_math on one microprogram_core through
-- merge_units() :
--
--   the math unit's result latency, measured at the data ram's ports :
--   programs k = 1 .. 27 at 36 * k issue a division and k instructions
--   later a second one that divides its quotient ; it must be what
--   fixed_math_result_latency() says. (A multiply-add there would write in
--   the clock of the division's write for one k, the scheduler keeps
--   them apart in the program below.)
--
--   a scheduled program of dependent divisions and multiply-adds, and a
--   repeat() of a division that reads its own quotient, checked against
--   lut_divide() and the multiply-add model
--
-- with no data ram address read in the clock it is written and no clock
-- where both units write.
entity math_unit_tb is
  generic (
      runner_cfg : string
      ;g_pre_add_register : boolean := false
      ;g_product_register : boolean := false
      ;g_data_ram_output_register : boolean := true
      ;g_data_width : natural := 32
      ;g_divider_shifter_stages : positive := 2
      ;g_math_ram_output_register  : boolean := true
      ;g_math_dsp_request_register : boolean := true
      -- forwarded data ram writes : the latencies the smallest k with the
      -- right result, a read in the clock of a write no collision
      ;g_data_forwarding : boolean := false
  );
end;

architecture vunit_simulation of math_unit_tb is

    use work.execution_unit_pkg.all;

    constant clock_period : time := 1 ns;
    signal clock : std_logic := '0';
    signal clock_count : natural := 0;

    constant radix : natural := 20;
    constant w     : natural := g_data_width;

    constant config : processor_config := (
        instruction_width => w
        ,data_width       => w
        ,radix            => radix
        ,result_latency   => fixed_point_result_latency(g_pre_add_register, g_product_register, g_data_ram_output_register
            , g_data_forwarding)
        ,delay_slots      => jump_delay_slots(true)
        ,math_latency     => fixed_math_result_latency(g_pre_add_register, g_product_register, g_data_ram_output_register,
            g_divider_shifter_stages, g_math_ram_output_register, g_math_dsp_request_register, g_data_forwarding)
        ,forwarded        => forwarded_clocks(g_data_ram_output_register, g_data_forwarding));

    constant ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 3, datawidth => w, addresswidth => 10);
    constant instr_ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 1, datawidth => w, addresswidth => 11);

    subtype word is std_logic_vector(w-1 downto 0);
    type word_array is array (natural range <>) of word;

    -- the latency programs at stride * k, the mixed program and the loop
    -- after them, in a 2048 word program ram
    constant mixed_start : natural := 1100;
    constant loop_start  : natural := 1500;
    constant stride : natural := 36;
    constant max_k  : natural := 27;

    -- the scheduled program and the loop
    constant mixed : microprogram := (
         mi_div(1, 64, 65)
        ,mi(mpy_add, 2, 1, 66, 67)    -- reads the quotient
        ,mi_div(3, 2, 68)             -- divides the multiply-add's result
        ,mi(mpy_add, 4, 69, 70, 71)   -- independent, its write meets the divisions'
        ,mi_div(5, 72, 73)
        ,mi_div(6, 73, 72)            -- back to back divisions
        ,mi(mpy_add, 7, 5, 6, 3)      -- reads three quotients
        ,mi_div(8, 75, 74)            -- 10 / 2.25
        ,mi_sqrt(9, 8)                -- the root of a quotient
        ,mi(mpy_add, 10, 9, 9, 74)    -- reads the root
        ,mi_sqrt(11, 76)              -- a root next to a division
        ,mi_sin(12, 77)               -- a quarter turn
        ,mi_cos(13, 77)
        ,mi_sin(14, 78)               -- an eighth
        ,mi_cos(15, 79)               -- -a third
        ,mi_div(16, 78, 74)           -- 0.125 / 2.25
        ,mi_sin(17, 16)               -- the sine of a quotient
        ,mi(mpy_add, 18, 17, 74, 13)  -- reads a sine and a cosine
        ,mi(program_end));

    function make_program return microprogram is
        variable retval : microprogram(0 to instr_ref_subtype.address_high) := empty_program(instr_ref_subtype.address_high + 1);
    begin
        for k in 1 to max_k loop
            retval(stride*k)         := mi_div(10 + k, 64, 65);
            retval(stride*k + k)     := mi_div(100 + k, 10 + k, 68);
            retval(stride*k + k + 1) := mi(program_end);
        end loop;
        retval := place(retval, mixed_start, schedule(config, mixed));
        -- x <- 2 / x, 10 rounds
        retval := place(retval, loop_start, repeat(config, 10, (0 => mi_div(80, 81, 80))) & mi(program_end));
        return retval;
    end make_program;


    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(w-1 downto 0)
        := encode(make_program, w);

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(w-1 downto 0)
        := encode_data((
            (64, 1.5), (65, -0.75), (66, 0.5), (67, 0.25), (68, 1.25),
            (69, -2.0), (70, 3.0), (71, 0.125), (72, 7.0), (73, -0.375),
            (74, 2.25), (75, 10.0), (76, 1234.5678),
            (77, 0.25), (78, 0.125), (79, -1.0 / 3.0),
            (80, 1.0), (81, 2.0)), config, ref_subtype.address_high + 1);

    -- the divider's table : 512 x 18 bits at radix 16, an 18 bit x_frac
    constant point_lut : reciprocal_lut_array := make_reciprocal_point_lut(9, 18, 16);
    constant slope_lut : reciprocal_lut_array := make_reciprocal_slope_lut(9, 18, 16);
    -- the square root's : 512 x 18 bits at radix 17, an 18 bit x_frac
    constant sqrt_point_lut : sqrt_lut_array := make_sqrt_point_lut(9, 18, 17);
    constant sqrt_slope_lut : sqrt_lut_array := make_sqrt_slope_lut(9, 18, 17);

    signal mproc_in  : microprogram_processor_in_record := (processor_requested => false, start_address => 0);
    signal mproc_out : microprogram_processor_out_record;

    signal mc_output   : ref_subtype.ram_write_in'subtype;
    signal mc_write_in : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    constant unit_in_ref : execution_unit_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to 31 => encode(mi(nop), w))
    );
    constant unit_out_ref : execution_unit_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
    );

    signal unit_in       : unit_in_ref'subtype  := unit_in_ref;
    signal unit_out      : unit_out_ref'subtype := unit_out_ref;
    signal mult_add_out  : unit_out_ref'subtype := unit_out_ref;
    signal math_out      : unit_out_ref'subtype := unit_out_ref;

    signal data_ram    : word_array(0 to ref_subtype.address_high) := (others => (others => '0'));
    signal collisions  : natural := 0;
    -- the latency sweep reads in the write clock on purpose, the monitor
    -- watches the scheduled programs
    signal watch_collisions : boolean := false;
    signal double_writes : natural := 0;

    type clock_array is array (0 to ref_subtype.address_high) of integer;
    signal write_clock : clock_array := (others => -1);
    signal read_clock  : clock_array := (others => -1);

begin

    clock <= not clock after clock_period/2;

    stimulus : process

        procedure run_program (start : natural) is
        begin
            wait until rising_edge(clock);
            mproc_in <= (processor_requested => true, start_address => start);
            wait until rising_edge(clock);
            mproc_in.processor_requested <= false;
            wait until rising_edge(clock) and is_ready(mproc_out) for 100 us;
            check(is_ready(mproc_out), "program " & integer'image(start) & " did not finish");
            for i in 1 to 30 loop
                wait until rising_edge(clock);
            end loop;
        end run_program;

        function m (address : natural) return word is
        begin
            return program_data(address);
        end m;

        function divide (a, b : word) return word is
        begin
            return std_logic_vector(lut_divide(signed(a), signed(b), radix, point_lut, slope_lut, 16, 18));
        end divide;

        function square_root (a : word) return word is
        begin
            return std_logic_vector(get_full_range_sqrt(unsigned(a), radix, sqrt_point_lut, sqrt_slope_lut, 17, 18));
        end square_root;

        -- the angle the 16 bits under the radix, 16 bits at radix 15 back
        function sine (a : word; quarter_turns : natural := 0) return word is
            variable angle : unsigned(15 downto 0) := unsigned(a(radix-1 downto radix-16));
        begin
            angle := angle + quarter_turns * 2**14;
            return std_logic_vector(shift_left(resize(get_sine_from_quarter_wave_lut(angle), w), radix - 15));
        end sine;

        function mult_add (a, b, c : word) return word is
            variable result : signed(2*w-1 downto 0);
        begin
            result := signed(a) * signed(b) + shift_left(resize(signed(c), 2*w), radix);
            return std_logic_vector(result(radix + w - 1 downto radix));
        end mult_add;

        procedure check_word (address : natural; expected : word) is
        begin
            check_equal(data_ram(address), expected, "data ram " & integer'image(address));
        end check_word;

        variable latency : integer := -1;
        variable q1, r2, q3, r4, q5, q6, q8, s9, q16, c13, s17, x : word;

    begin
        test_runner_setup(runner, runner_cfg);
        info("pre-adder register " & boolean'image(g_pre_add_register)
            & ", product register " & boolean'image(g_product_register)
            & ", data ram output register " & boolean'image(g_data_ram_output_register)
            & ", " & integer'image(w) & " bit : math latency " & integer'image(config.math_latency)
            & ", multiply-add latency " & integer'image(config.result_latency));

        -- the latency, at the ram's ports
        for k in 1 to max_k loop
            run_program(stride*k);
            check_word(10 + k, divide(m(64), m(65)));
            if (read_clock(10 + k) > write_clock(10 + k)
                    or (g_data_forwarding and data_ram(100 + k) = divide(divide(m(64), m(65)), m(68))))
                and latency < 0
            then
                latency := k;
            end if;
            if latency > 0 then
                check_word(100 + k, divide(divide(m(64), m(65)), m(68)));
            end if;
        end loop;
        info("measured math latency " & integer'image(latency));
        check_equal(latency, config.math_latency, "fixed_math_result_latency()");

        -- the scheduled program
        watch_collisions <= not g_data_forwarding;
        run_program(mixed_start);
        q1 := divide(m(64), m(65));
        r2 := mult_add(q1, m(66), m(67));
        q3 := divide(r2, m(68));
        r4 := mult_add(m(69), m(70), m(71));
        q5 := divide(m(72), m(73));
        q6 := divide(m(73), m(72));
        check_word(1, q1);
        check_word(2, r2);
        check_word(3, q3);
        check_word(4, r4);
        check_word(5, q5);
        check_word(6, q6);
        check_word(7, mult_add(q5, q6, q3));
        q8 := divide(m(75), m(74));
        s9 := square_root(q8);
        check_word(8, q8);
        check_word(9, s9);
        check_word(10, mult_add(s9, s9, m(74)));
        check_word(11, square_root(m(76)));
        c13 := sine(m(77), 1);
        check_word(12, sine(m(77)));
        check_word(13, c13);
        check_word(14, sine(m(78)));
        check_word(15, sine(m(79), 1));
        q16 := divide(m(78), m(74));
        s17 := sine(q16);
        check_word(16, q16);
        check_word(17, s17);
        check_word(18, mult_add(s17, m(74), c13));
        info("sin(1/4 turn) " & real'image(real(to_integer(signed(sine(m(77))))) / 2.0**radix)
            & ", cos(-1/3 turn) " & real'image(real(to_integer(signed(sine(m(79), 1)))) / 2.0**radix));

        -- the loop
        run_program(loop_start);
        x := m(80);
        for k in 1 to 10 loop
            x := divide(m(81), x);
        end loop;
        check_word(80, x);

        check_equal(collisions, 0, "data ram reads in the clock of a write to the address");
        check_equal(double_writes, 0, "clocks where both units write");

        test_runner_cleanup(runner);
        wait;
    end process stimulus;

    test_runner_watchdog(runner, 5 ms);

    count_clocks : process (clock) is
    begin
        if rising_edge(clock) then
            clock_count <= clock_count + 1;
        end if;
    end process count_clocks;

    watch_ram : process (clock) is
    begin
        if rising_edge(clock) then
            for port_index in unit_out.data_read_in'range loop
                if unit_out.data_read_in(port_index).read_requested = '1' then
                    read_clock(to_integer(unit_out.data_read_in(port_index).address)) <= clock_count;
                end if;
            end loop;
            if mc_output.write_requested = '1' then
                write_clock(to_integer(mc_output.address)) <= clock_count;
                data_ram(to_integer(mc_output.address)) <= mc_output.data;
                for port_index in unit_out.data_read_in'range loop
                    if watch_collisions
                        and unit_out.data_read_in(port_index).read_requested = '1'
                        and unit_out.data_read_in(port_index).address = mc_output.address
                    then
                        collisions <= collisions + 1;
                        error("data ram " & integer'image(to_integer(mc_output.address))
                            & " read in the clock it is written");
                    end if;
                end loop;
            end if;
            if mult_add_out.ram_write_in.write_requested = '1' and math_out.ram_write_in.write_requested = '1' then
                double_writes <= double_writes + 1;
                error("both units write in one clock");
            end if;
        end if;
    end process watch_ram;

    unit_out <= merge_units(mult_add_out, math_out);

    u_microprogram_core : entity work.microprogram_core
    generic map (g_program => test_program, g_data => program_data
        ,g_data_ram_output_register => g_data_ram_output_register
        ,g_data_forwarding => g_data_forwarding)
    port map (
        clock        => clock
        ,mproc_in    => mproc_in
        ,mproc_out   => mproc_out
        ,mc_output   => mc_output
        ,mc_write_in => mc_write_in
        ,to_unit     => unit_in
        ,from_unit   => unit_out
    );

    u_fixed_mult_add : entity work.execution_unit(fixed_mult_add)
    generic map (g_radix => radix, g_pre_add_register => g_pre_add_register, g_product_register => g_product_register
        ,g_data_ram_output_register => g_data_ram_output_register)
    port map (clock, unit_in, mult_add_out);

    u_fixed_math : entity work.execution_unit(fixed_math)
    generic map (g_radix => radix, g_pre_add_register => g_pre_add_register, g_product_register => g_product_register
        ,g_data_ram_output_register => g_data_ram_output_register, g_divider_shifter_stages => g_divider_shifter_stages
        ,g_math_ram_output_register => g_math_ram_output_register, g_math_dsp_request_register => g_math_dsp_request_register)
    port map (clock, unit_in, math_out);

end vunit_simulation;
