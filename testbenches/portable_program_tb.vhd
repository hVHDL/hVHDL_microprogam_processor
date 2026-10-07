LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.all;
    use work.microprogram_assembler_pkg.all;

-- one program source, laid out by microprogram_assembler_pkg for the
-- configuration in the generics, every result checked against a model and
-- no data ram address read in the clock it is written :
--
--   0   : a chain of dependent multiply-adds and the accumulator
--   128 : 50 rounds of the boost converter step, repeat()
--   256 : 100 rounds of the low pass filter y <- (u - y) * g + y, a one
--         instruction body that reads its own result
entity portable_program_tb is
  generic (
      runner_cfg : string
      ;g_architecture      : string  := "fixed_mult_add"
      ;g_pre_add_register  : boolean := false
      ;g_product_register  : boolean := false
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
        ,result_latency   => fixed_point_result_latency(g_pre_add_register, g_product_register));

    constant ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 3, datawidth => w, addresswidth => 10);
    constant instr_ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 1, datawidth => g_instruction_width, addresswidth => 10);

    subtype word is std_logic_vector(w-1 downto 0);
    type word_array is array (natural range <>) of word;

    ------------------------------------------------------------------------
    -- the program source, the same for every configuration
    ------------------------------------------------------------------------
    type boost_map is record
        vin, duty, load, r, i_gain, u_gain, i, u, vl, ic : natural;
    end record;
    constant boost : boost_map := (vin => 100, duty => 101, load => 102, r => 103, i_gain => 104,
        u_gain => 105, i => 106, u => 107, vl => 108, ic => 109);

    function boost_step (m : boost_map) return microprogram is
    begin
        return (mi(neg_mpy_add , m.vl , m.duty , m.u      , m.vin)
               ,mi(mpy_sub     , m.ic , m.duty , m.i      , m.load)
               ,mi(neg_mpy_add , m.vl , m.r    , m.i      , m.vl)
               ,mi(mpy_add     , m.u  , m.ic   , m.u_gain , m.u)
               ,mi(mpy_add     , m.i  , m.vl   , m.i_gain , m.i));
    end boost_step;

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
        retval := place(retval, 128, repeat(config, 50, boost_step(boost)) & mi(program_end));
        retval := place(retval, 256, repeat(config, 100, (0 => mi(lp_filter, 96, 97, 96, 98))) & mi(program_end));
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

    function to_fixed (x : real) return word is
    begin
        return std_logic_vector(to_signed(integer(x * 2.0**radix), w));
    end to_fixed;

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
        retval(boost.vin)    := to_fixed(10.0);
        retval(boost.duty)   := to_fixed(0.5);
        retval(boost.load)   := to_fixed(0.25);
        retval(boost.r)      := to_fixed(0.8);
        retval(boost.i_gain) := to_fixed(0.7 / 3.0);
        retval(boost.u_gain) := to_fixed(0.7 / 3.0);
        retval(boost.i)      := to_fixed(1.0);
        retval(boost.u)      := to_fixed(5.0);
        retval(96) := to_fixed(0.0);
        retval(97) := to_fixed(3.0);
        retval(98) := to_fixed(0.05);
        return retval;
    end make_data;

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(w-1 downto 0) := make_data;

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

    begin
        test_runner_setup(runner, runner_cfg);
        info(g_architecture & ", pre-adder register " & boolean'image(g_pre_add_register)
            & ", product register " & boolean'image(g_product_register)
            & ", " & integer'image(g_data_width) & " bit data, " & integer'image(g_instruction_width)
            & " bit instructions : result latency " & integer'image(config.result_latency));

        run_program(0, clocks);
        info("chain : " & integer'image(clocks) & " clocks");
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

        run_program(128, clocks);
        info("50 boost converter steps : " & integer'image(clocks) & " clocks");
        i := m(boost.i);
        u := m(boost.u);
        for k in 1 to 50 loop
            vl := mult_add(minus(m(boost.duty)), u, m(boost.vin));
            ic := mult_sub(m(boost.duty), i, m(boost.load));
            vl := mult_add(minus(m(boost.r)), i, vl);
            u  := mult_add(ic, m(boost.u_gain), u);
            i  := mult_add(vl, m(boost.i_gain), i);
        end loop;
        check_word(boost.i, i);
        check_word(boost.u, u);

        run_program(256, clocks);
        info("100 low pass filter rounds : " & integer'image(clocks) & " clocks");
        y := m(96);
        for k in 1 to 100 loop
            y := mult_add(sum(m(97), minus(y)), m(98), y);
        end loop;
        check_word(96, y);

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
                    if unit_out.data_read_in(port_index).read_requested = '1'
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
    generic map (g_program => test_program, g_data => program_data)
    port map (
        clock        => clock
        ,mproc_in    => mproc_in
        ,mproc_out   => mproc_out
        ,mc_output   => mc_output
        ,mc_write_in => mc_write_in
        ,to_unit     => unit_in
        ,from_unit   => unit_out
    );

    fixed_mult_add : if g_architecture = "fixed_mult_add" generate
        u_instruction : entity work.execution_unit(fixed_mult_add)
        generic map (g_radix => radix, g_pre_add_register => g_pre_add_register, g_product_register => g_product_register)
        port map (clock, unit_in, unit_out);
    end generate;

    fixed_mult_acc : if g_architecture = "fixed_mult_acc" generate
        u_instruction : entity work.execution_unit(fixed_mult_acc)
        generic map (g_radix => radix, g_pre_add_register => g_pre_add_register, g_product_register => g_product_register)
        port map (clock, unit_in, unit_out);
    end generate;

end vunit_simulation;
