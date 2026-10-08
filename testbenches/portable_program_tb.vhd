LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.all;
    use work.microprogram_assembler_pkg.all;
    use work.boost_converter_pkg.all;

-- one program source, laid out by microprogram_assembler_pkg for the
-- configuration in the generics, every result checked against a model and
-- no data ram address read in the clock it is written :
--
--   0   : a chain of dependent multiply-adds and the accumulator
--   128 : 50 rounds of the boost converter step, repeat()
--   256 : 100 rounds of the low pass filter y <- (u - y) * g + y, a one
--         instruction body that reads its own result
--
-- and for the program cache, programs it must not cache :
--
--   400 : a jump in the cache line's span, at 401 on to 410 (an acc
--         of 65 at 405 if it were not taken) : 2 * 64 + 65 into 9
--   440 : a program_end in the line's span
--   470 : the chain again, never a static line
--   600, 620 .. 680 : a multiply-add each, for the dynamic lines
--
-- 128 and 256 start with repeat()'s set_rpt, from the line on a hit.
-- Every run's length is checked against a model of the cache : with the
-- line depth added back on a predicted hit, a program's runs are all as
-- long.
entity portable_program_tb is
  generic (
      runner_cfg : string
      ;g_pre_add_register  : boolean := false
      ;g_product_register  : boolean := false
      ;g_program_ram_output_register : boolean := true
      ;g_data_ram_output_register    : boolean := true
      -- forwarded data ram writes, the programs laid out for the shorter
      -- latency, a read in the clock of a write no collision
      ;g_data_forwarding : boolean := false
      -- the sequencer's program cache : every program runs twice, the
      -- second start from the cache line, jump_delay_slots() clocks shorter
      ;g_program_cache : boolean := false
      ;g_dynamic_lines : positive := 1
      -- static cache lines for programs 0 and 128 : a hit from the first
      -- start on, the chain's first run the depth shorter than 470's
      ;g_static_cache : boolean := false
      ;g_data_width        : natural := 32
      ;g_instruction_width : natural := 32
  );
end;

architecture vunit_simulation of portable_program_tb is

    use work.execution_unit_pkg.all;

    constant clock_period : time := 1 ns;
    signal clock : std_logic := '0';
    signal clock_count : natural := 0;

    constant radix : natural := 20;
    constant w     : natural := g_data_width;

    constant config : processor_config := (
        instruction_width => g_instruction_width
        ,data_width       => g_data_width
        ,radix            => radix
        ,result_latency   => fixed_point_result_latency(g_pre_add_register, g_product_register, g_data_ram_output_register
            , g_data_forwarding)
        ,delay_slots      => jump_delay_slots(g_program_ram_output_register)
        ,math_latency     => 0
        ,forwarded        => forwarded_clocks(g_data_ram_output_register, g_data_forwarding));

    constant ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 3, datawidth => w, addresswidth => 10);
    constant instr_ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 1, datawidth => g_instruction_width, addresswidth => 10);

    subtype word is std_logic_vector(w-1 downto 0);
    type word_array is array (natural range <>) of word;

    ------------------------------------------------------------------------
    -- the program source, the same for every configuration
    ------------------------------------------------------------------------
    constant boost : boost_converter_map := boost_converter_at(100);
    constant boost_values : boost_converter_values := (vin => 10.0, duty => 0.5, load => 0.25, r => 0.8,
        i_gain => 0.7 / 3.0, u_gain => 0.7 / 3.0, i => 1.0, u => 5.0);

    constant chain : microprogram := (
         mi(mpy_add          , 1 , 64 , 65 , 66)
        ,mi(mpy_sub          , 2 , 1  , 67 , 68)  -- reads 1
        ,mi(neg_mpy_add      , 3 , 2  , 69 , 1)   -- reads 2 and 1
        ,mi(lp_filter        , 4 , 3  , 2  , 70)  -- (3 - 2) * 70 + 2
        ,mi(a_add_b_mpy_c    , 5 , 4  , 1  , 71)  -- (4 + 1) * 71
        ,mi(acc              , 0 , 0  , 0  , 5)
        ,mi(acc              , 0 , 0  , 0  , 4)
        ,mi(get_acc_and_zero , 6 , 0  , 0  , 3)   -- 5 + 4 + 3
        ,mi(acc              , 0 , 0  , 0  , 1)   -- after the accumulator is zeroed
        ,mi(get_acc_and_zero , 7 , 0  , 0  , 2)   -- 1 + 2
        ,mi(program_end));

    function make_program return microprogram is
        variable retval : microprogram(0 to instr_ref_subtype.address_high) := empty_program(instr_ref_subtype.address_high + 1);
    begin
        retval := place(retval, 0,   schedule(config, chain));
        retval := place(retval, 128, repeat(config, 50, boost_converter_step(boost)) & mi(program_end));
        retval := place(retval, 256, repeat(config, 100, (0 => mi(lp_filter, 96, 97, 96, 98))) & mi(program_end));
        retval := place(retval, 400, (mi(set_rpt, 1), mi(jump, 410)));
        retval := place(retval, 405, (0 => mi(acc, 0, 0, 0, 65)));
        retval := place(retval, 410, schedule(config, (mi(acc, 0, 0, 0, 64), mi(acc, 0, 0, 0, 64)
            , mi(get_acc_and_zero, 9, 0, 0, 65), mi(program_end))));
        retval := place(retval, 440, (mi(acc, 0, 0, 0, 64), mi(program_end)));
        retval := place(retval, 470, schedule(config, chain));
        for k in 0 to 4 loop
            retval := place(retval, 600 + 20 * k, schedule(config, (mi(mpy_add, 20 + k, 64, 65, 66), mi(program_end))));
        end loop;
        return retval;
    end make_program;

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(instr_ref_subtype.data'range)
        := encode(make_program, g_instruction_width);

    ------------------------------------------------------------------------
    function galois_step (x : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        if x(0) = '1' then
            return ('0' & x(31 downto 1)) xor x"80200003";
        end if;
        return '0' & x(31 downto 1);
    end galois_step;

    function make_data return work.dual_port_ram_pkg.ram_array is
        variable retval : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(w-1 downto 0)
            := (others => (others => '0'));
        variable x : std_logic_vector(31 downto 0) := x"1234abcd";
    begin
        -- operands of about -1 .. 3, so the chain stays in range
        for i in 64 to 71 loop
            x := galois_step(x);
            retval(i) := std_logic_vector(resize(signed(x(23 downto 0)) / 4 + 2**radix, w));
        end loop;
        return set_data(retval, boost_converter_data(boost, boost_values)
            & data_list'((96, 0.0), (97, 3.0), (98, 0.05)), config);
    end make_data;

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(w-1 downto 0) := make_data;

    function cached_programs return program_start_array is
    begin
        if g_static_cache then
            return (0, 128);
        end if;
        return (1 to 0 => 0);
    end cached_programs;

    function is_static (start : natural) return boolean is
    begin
        return g_static_cache and (start = 0 or start = 128);
    end is_static;

    signal mproc_in  : microprogram_processor_in_record := (processor_requested => false, start_address => 0);
    signal mproc_out : microprogram_processor_out_record;

    signal mc_output   : ref_subtype.ram_write_in'subtype;
    signal mc_write_in : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    constant unit_in_ref : execution_unit_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to 12 => encode(mi(nop), g_instruction_width))
    );
    constant unit_out_ref : execution_unit_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
    );

    signal unit_in  : unit_in_ref'subtype  := unit_in_ref;
    signal unit_out : unit_out_ref'subtype := unit_out_ref;

    signal data_ram   : word_array(0 to ref_subtype.address_high) := (others => (others => '0'));
    signal collisions : natural := 0;

    type natural_list is array (natural range <>) of natural;
    type boolean_list is array (natural range <>) of boolean;

begin

    clock <= not clock after clock_period/2;

    stimulus : process

        -- ready marks the results as readable : the scheduler places
        -- program_end after them
        procedure run_program (start : natural; clocks : out natural) is
            variable started : natural;
        begin
            wait until rising_edge(clock);
            mproc_in <= (processor_requested => true, start_address => start);
            started := clock_count;
            wait until rising_edge(clock);
            mproc_in.processor_requested <= false;
            wait until rising_edge(clock) and is_ready(mproc_out) for 100 us;
            check(is_ready(mproc_out), "program " & integer'image(start) & " did not finish");
            clocks := clock_count - started;
            wait until rising_edge(clock);
        end run_program;

        ------------------------------------------------------------------
        -- the cache's model : the static lines, the dynamic lines filled in
        -- turn on a miss, not by a program with a jump or program_end in
        -- its line's span
        ------------------------------------------------------------------
        variable tags      : natural_list(0 to g_dynamic_lines-1) := (others => 0);
        variable valid     : boolean_list(0 to g_dynamic_lines-1) := (others => false);
        variable next_line : natural := 0;
        -- a program's length without the cache, 0 before its first run
        variable uncached  : natural_list(0 to 1023) := (others => 0);
        variable hits      : natural := 0;

        -- no jump or program_end in the line's span : with forwarding the
        -- low pass filter's shorter loop puts its jump there
        function cacheable (start : natural) return boolean is
        begin
            for k in 0 to config.delay_slots-1 loop
                if decode(test_program(start + k)) = jump or decode(test_program(start + k)) = program_end then
                    return false;
                end if;
            end loop;
            return true;
        end cacheable;

        procedure predict (start : natural; hit : out boolean) is
        begin
            hit := is_static(start);
            if g_program_cache and not hit then
                for line in tags'range loop
                    if valid(line) and tags(line) = start then
                        hit := true;
                    end if;
                end loop;
                if not hit then
                    tags(next_line)  := start;
                    valid(next_line) := cacheable(start);
                    next_line        := (next_line + 1) mod g_dynamic_lines;
                end if;
            end if;
        end predict;

        -- a run, its length checked against the model's
        procedure run_checked (start : natural; clocks : out natural; hit : out boolean) is
            variable predicted : boolean;
            variable length    : natural;
        begin
            predict(start, predicted);
            run_program(start, length);
            length := length + config.delay_slots * boolean'pos(predicted);
            if uncached(start) = 0 then
                uncached(start) := length;
            end if;
            check_equal(length, uncached(start), "program " & integer'image(start)
                & ", the cache model's hit " & boolean'image(predicted));
            hits   := hits + boolean'pos(predicted);
            clocks := length - config.delay_slots * boolean'pos(predicted);
            hit    := predicted;
        end run_checked;

        procedure run_checked (start : natural) is
            variable clocks : natural;
            variable hit    : boolean;
        begin
            run_checked(start, clocks, hit);
        end run_checked;

        -- a program once, or with a cache twice : a static line's program is
        -- as long again, a dynamic one's second start hits the line its
        -- first filled and is the line's depth shorter
        procedure run_cached (start : natural; clocks : out natural) is
            variable first, second : natural;
            variable hit : boolean;
        begin
            run_checked(start, first, hit);
            clocks := first;
            if g_program_cache or g_static_cache then
                run_checked(start, second, hit);
                check(hit or not ((g_program_cache and cacheable(start)) or is_static(start)),
                    "program " & integer'image(start) & " from the cache the second time");
                info("program " & integer'image(start) & " : " & integer'image(first)
                    & " clocks, again " & integer'image(second));
            end if;
        end run_cached;

        constant runs : natural := 1 + boolean'pos(g_program_cache or g_static_cache);

        function m (address : natural) return word is
        begin
            return program_data(address);
        end m;

        function mult_add (a, b, c : word) return word is
            variable result : signed(2*w-1 downto 0);
        begin
            result := signed(a) * signed(b) + shift_left(resize(signed(c), 2*w), radix);
            return std_logic_vector(result(radix + w - 1 downto radix));
        end mult_add;

        function mult_sub (a, b, c : word) return word is
            variable result : signed(2*w-1 downto 0);
        begin
            result := signed(a) * signed(b) - shift_left(resize(signed(c), 2*w), radix);
            return std_logic_vector(result(radix + w - 1 downto radix));
        end mult_sub;

        function sum (a, b : word) return word is
        begin
            return std_logic_vector(signed(a) + signed(b));
        end sum;

        function minus (a : word) return word is
        begin
            return std_logic_vector(-signed(a));
        end minus;

        constant zero : word := (others => '0');

        procedure check_word (address : natural; expected : word) is
        begin
            check_equal(data_ram(address), expected, "data ram " & integer'image(address));
        end check_word;

        variable r1, r2, r3, r4, r5 : word;
        variable i, u, vl, ic, y    : word;
        variable clocks : natural;
        variable first, again, first_chain, chain_first : natural;
        variable hit : boolean;
        -- the cacheable programs the dynamic lines take in turn
        constant dynamic_programs : natural_list := (470, 600, 620, 640, 660, 680);

    begin
        test_runner_setup(runner, runner_cfg);
        info("pre-adder register " & boolean'image(g_pre_add_register)
            & ", product register " & boolean'image(g_product_register)
            & ", " & integer'image(g_data_width) & " bit data, " & integer'image(g_instruction_width)
            & " bit instructions, program / data ram output registers "
            & boolean'image(g_program_ram_output_register) & " / " & boolean'image(g_data_ram_output_register)
            & " : result latency " & integer'image(config.result_latency)
            & ", jump delay slots " & integer'image(config.delay_slots));

        -- to_fixed() at the data width : beyond a 32 bit integer, negative,
        -- half an lsb rounded away from zero
        check_equal(to_fixed(-2.5, config), std_logic_vector(shift_left(to_signed(-5, w), radix - 1)), "to_fixed(-2.5)");
        check_equal(to_fixed(2.0**(-radix-1), config), std_logic_vector(to_signed(1, w)), "to_fixed(half an lsb)");
        check_equal(to_fixed(-2.0**(-radix-1), config), std_logic_vector(to_signed(-1, w)), "to_fixed(-half an lsb)");
        check_equal(to_fixed(1000.0 + 2.0**(-radix), config),
            std_logic_vector(shift_left(to_signed(1000, w), radix) + 1), "to_fixed(1000 + lsb)");
        if w > 32 then
            check_equal(to_fixed(3000.0, config), std_logic_vector(shift_left(to_signed(3000, w), radix)), "to_fixed(3000)");
            check_equal(to_fixed(-3000.0 - 2.0**(-radix), config),
                std_logic_vector(shift_left(to_signed(-3000, w), radix) - 1), "to_fixed(-3000 - lsb)");
        end if;

        run_cached(0, clocks);
        info("chain : " & integer'image(clocks) & " clocks");
        chain_first := clocks;
        r1 := mult_add(m(64), m(65), m(66));
        r2 := mult_sub(r1, m(67), m(68));
        r3 := mult_add(minus(r2), m(69), r1);
        r4 := mult_add(sum(r3, minus(r2)), m(70), r2);
        r5 := mult_add(sum(r4, r1), m(71), zero);
        check_word(1, r1);
        check_word(2, r2);
        check_word(3, r3);
        check_word(4, r4);
        check_word(5, r5);
        check_word(6, sum(sum(r5, r4), r3));
        check_word(7, sum(r1, r2));

        run_cached(128, clocks);
        info("50 boost converter steps : " & integer'image(clocks) & " clocks");
        i := m(boost.i);
        u := m(boost.u);
        for k in 1 to 50 * runs loop
            vl := mult_add(minus(m(boost.duty)), u, m(boost.vin));
            ic := mult_sub(m(boost.duty), i, m(boost.load));
            vl := mult_add(minus(m(boost.r)), i, vl);
            u  := mult_add(ic, m(boost.u_gain), u);
            i  := mult_add(vl, m(boost.i_gain), i);
        end loop;
        check_word(boost.i, i);
        check_word(boost.u, u);

        run_cached(256, clocks);
        info("100 low pass filter rounds : " & integer'image(clocks) & " clocks");
        y := m(96);
        for k in 1 to 100 * runs loop
            y := mult_add(sum(m(97), minus(y)), m(98), y);
        end loop;
        check_word(96, y);

        if g_program_cache then
            -- the spans the line would take hold a jump and a program_end
            check(decode(test_program(401)) = jump and decode(test_program(441)) = program_end,
                "programs 400 and 440 have a jump and a program_end in the line's span");

            -- a jump or a program_end in the span : not cached, the same
            -- length again, 400's jump taken both times
            -- (440 leaves the accumulator at 64, after 400's checks)
            for k in 1 to 2 loop
                run_checked(400, clocks, hit);
                check(not hit, "program 400, a jump in the line's span, not cached");
                check_word(9, sum(sum(m(64), m(64)), m(65)));
            end loop;
            for k in 1 to 2 loop
                run_checked(440, clocks, hit);
                check(not hit, "program 440, a program_end in the line's span, not cached");
            end loop;

            -- as many programs as dynamic lines in turn stay cached, one
            -- more and each start replaces the line its next start needs
            for programs in g_dynamic_lines to g_dynamic_lines + 1 loop
                for round in 1 to 3 loop
                    for k in 0 to programs-1 loop
                        run_checked(dynamic_programs(k), clocks, hit);
                        if round > 1 then
                            check(hit = (programs = g_dynamic_lines), "program " & integer'image(dynamic_programs(k))
                                & " with " & integer'image(programs) & " programs in turn");
                        end if;
                    end loop;
                end loop;
            end loop;

            -- a static line's program does not take a dynamic line
            for k in 0 to g_dynamic_lines-1 loop
                run_checked(dynamic_programs(k));
            end loop;
            run_checked(128, clocks, hit);
            check(hit = is_static(128), "program 128");
            for k in 0 to g_dynamic_lines-1 loop
                run_checked(dynamic_programs(k), clocks, hit);
                if is_static(128) then
                    check(hit, "program " & integer'image(dynamic_programs(k)) & " after the static 128");
                end if;
            end loop;
            info(integer'image(g_dynamic_lines) & " dynamic lines : " & integer'image(g_dynamic_lines)
                & " programs in turn cached, " & integer'image(g_dynamic_lines + 1) & " not, 400 and 440 never");
        end if;

        if g_static_cache then
            -- 0 from its static line from the first start on, 470 the same
            -- code from the ram
            run_checked(470);
            check_equal(chain_first, uncached(470) - config.delay_slots, "program 0 from its static line");
            info("program 0 from its static line : " & integer'image(chain_first) & " clocks, 470 : "
                & integer'image(uncached(470)));
        end if;

        info(integer'image(hits) & " runs from the cache");
        check_equal(collisions, 0, "data ram reads in the clock of a write to the address");

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

    -- the data ram's ports : the writes, and any read of an address in the
    -- clock it is written, a port collision
    watch_ram : process (clock) is
    begin
        if rising_edge(clock) then
            if mc_output.write_requested = '1' then
                data_ram(to_integer(mc_output.address)) <= mc_output.data;
                for port_index in unit_out.data_read_in'range loop
                    if not g_data_forwarding
                        and unit_out.data_read_in(port_index).read_requested = '1'
                        and unit_out.data_read_in(port_index).address = mc_output.address
                    then
                        collisions <= collisions + 1;
                        error("data ram " & integer'image(to_integer(mc_output.address))
                            & " read in the clock it is written");
                    end if;
                end loop;
            end if;
        end if;
    end process watch_ram;

    u_microprogram_core : entity work.microprogram_core
    generic map (g_program => test_program, g_data => program_data
        ,g_program_ram_output_register => g_program_ram_output_register
        ,g_data_ram_output_register => g_data_ram_output_register
        ,g_data_forwarding => g_data_forwarding
        ,g_program_cache => g_program_cache
        ,g_dynamic_lines => g_dynamic_lines
        ,g_cached_programs => cached_programs)
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
    port map (clock, unit_in, unit_out);

end vunit_simulation;
