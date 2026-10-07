LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.all;

-- runs programs on microprogram_core with the fixed point
-- instruction architecture g_architecture (fixed_mult_add or fixed_mult_acc)
-- and checks every result against a model of the arithmetic
entity fixed_execution_unit_tb is
  generic (
      runner_cfg : string
      ;g_architecture     : string  := "fixed_mult_add"
      ;g_pre_add_register : boolean := false
      ;g_product_register : boolean := false
      -- the program ram is 2**g_program_address_width words
      ;g_program_address_width : natural := 10
      -- the data and program ram word widths
      ;g_data_width        : natural := 32
      ;g_instruction_width : natural := 32
  );
end;

architecture vunit_simulation of fixed_execution_unit_tb is

    constant clock_period : time := 1 ns;
    signal clock : std_logic := '0';

    constant radix : natural := 20;

    constant ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 3, datawidth => g_data_width, addresswidth => 10);
    constant instr_ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 1, datawidth => g_instruction_width, addresswidth => g_program_address_width);

    constant w : natural := g_data_width;
    subtype word is std_logic_vector(w-1 downto 0);
    type word_array is array (natural range <>) of word;

    function galois_step (x : std_logic_vector(31 downto 0)) return std_logic_vector is
    begin
        if x(0) = '1' then
            return ('0' & x(31 downto 1)) xor x"80200003";
        end if;
        return '0' & x(31 downto 1);
    end galois_step;

    -- operands 64..95 random, two of them the most negative number for
    -- the pre-adder's wrap ; 96..98 the low pass filter's y, u and g
    function make_data return work.dual_port_ram_pkg.ram_array is
        variable retval : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(ref_subtype.data'range)
            := (others => (others => '0'));
        variable x : std_logic_vector(31 downto 0) := x"1234abcd";
        constant most_negative : word := '1' & (w-2 downto 0 => '0');
    begin
        -- random 32 bit operands, shifted up to the data width
        for i in 64 to 95 loop
            x := galois_step(x);
            retval(i) := std_logic_vector(shift_left(resize(shift_right(signed(x), 2), w), w - 32));
        end loop;
        retval(70) := most_negative;
        retval(80) := most_negative;
        retval(96) := std_logic_vector(to_signed(0, w));
        retval(97) := std_logic_vector(to_signed(3 * 2**radix, w));
        retval(98) := std_logic_vector(to_signed(2**radix / 20, w));
        for i in 200 to 205 loop
            x := galois_step(x);
            retval(i) := std_logic_vector(shift_left(resize(shift_right(signed(x), 2), w), w - 32));
        end loop;
        return retval;
    end make_data;

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(ref_subtype.data'range) := make_data;

    function make_program return microprogram is
        variable retval : microprogram(0 to instr_ref_subtype.address_high) := (others => mi(nop));
    begin
        retval := (
        -- 0 : one of each multiply-add, the accumulator, the accumulator
        -- zeroed by get_acc_and_zero
        0    => mi(mpy_add          , 1 , 64 , 65 , 66)
        , 1  => mi(mpy_sub          , 2 , 67 , 68 , 69)
        , 2  => mi(neg_mpy_add      , 3 , 70 , 71 , 72)
        , 3  => mi(neg_mpy_sub      , 4 , 73 , 74 , 75)
        , 4  => mi(a_add_b_mpy_c    , 5 , 76 , 77 , 78)
        , 5  => mi(a_sub_b_mpy_c    , 6 , 79 , 80 , 81)
        , 6  => mi(lp_filter        , 7 , 82 , 83 , 84)
        , 7  => mi(acc              , 0 , 0  , 0  , 89)
        , 8  => mi(acc              , 0 , 0  , 0  , 90)
        , 9  => mi(get_acc_and_zero , 8 , 0  , 0  , 91)
        , 20 => mi(get_acc_and_zero , 9 , 0  , 0  , 0)
        , 24 => mi(program_end)

        -- 32 : products into the accumulator, fixed_mult_acc only
        , 32 => mi(mpy_acc          , 0  , 85 , 86 , 0)
        , 33 => mi(mpy_acc          , 0  , 87 , 88 , 0)
        , 34 => mi(acc              , 0  , 0  , 0  , 92)
        , 35 => mi(get_acc_and_zero , 10 , 0  , 0  , 93)
        , 40 => mi(program_end)

        -- 64 : 100 rounds of y <- (u - y) * g + y
        , 64 => mi(set_rpt   , 99)
        , 65 => mi(lp_filter , 96 , 97 , 96 , 98)
        , 81 => mi(jump      , 65)
        , 85 => mi(program_end)

        , others => mi(nop));
        -- 96 : operands and result above 127, for address fields of 8 bits
        -- and up
        if address_bits(g_instruction_width) >= 8 then
            retval(96)  := mi(mpy_add, 250, 200, 201, 202);
            retval(97)  := mi(mpy_sub, 251, 203, 204, 205);
            retval(100) := mi(program_end);
        end if;
        return retval;
    end make_program;

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(instr_ref_subtype.data'range)
        := encode(make_program, g_instruction_width);

    signal mproc_in  : microprogram_processor_in_record := (processor_requested => false, start_address => 0);
    signal mproc_out : microprogram_processor_out_record;

    signal mc_output   : ref_subtype.ram_write_in'subtype;
    signal mc_write_in : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    use work.execution_unit_pkg.all;
    constant unit_in_ref : execution_unit_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to 12 => encode(mi(nop), g_instruction_width))
    );
    constant unit_out_ref : execution_unit_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
    );

    signal instr_in  : unit_in_ref'subtype  := unit_in_ref;
    signal instr_out : unit_out_ref'subtype := unit_out_ref;

    -- the data ram as the processor writes it
    signal data_ram : word_array(0 to ref_subtype.address_high) := (others => (others => '0'));

begin

    clock <= not clock after clock_period/2;

    stimulus : process

        procedure run_program (start : natural) is
        begin
            wait until rising_edge(clock);
            mproc_in <= (processor_requested => true, start_address => start);
            wait until rising_edge(clock);
            mproc_in.processor_requested <= false;
            wait until rising_edge(clock) and is_ready(mproc_out) for 10 us;
            check(is_ready(mproc_out), "program " & integer'image(start) & " did not finish");
            -- the last results land a few clocks after ready
            for i in 1 to 10 loop
                wait until rising_edge(clock);
            end loop;
        end run_program;

        function m (address : natural) return word is
        begin
            return program_data(address);
        end m;

        -- bits radix + w - 1 downto radix of a * b + c * 2**radix
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

        -- the pre-adder, wraps to the data width
        function sum (a, b : word) return word is
        begin
            return std_logic_vector(signed(a) + signed(b));
        end sum;

        function minus (a : word) return word is
        begin
            return std_logic_vector(-signed(a));
        end minus;

        procedure check_word (address : natural; expected : word) is
        begin
            check_equal(data_ram(address), expected, "data ram " & integer'image(address));
        end check_word;

        constant zero     : word := (others => '0');
        variable products : signed(2*w-1 downto 0);
        variable y        : word;

    begin
        test_runner_setup(runner, runner_cfg);
        info(g_architecture & ", pre-adder register " & boolean'image(g_pre_add_register)
            & ", product register " & boolean'image(g_product_register)
            & ", " & integer'image(test_program'length) & " word program ram, "
            & integer'image(g_data_width) & " bit data, " & integer'image(g_instruction_width) & " bit instructions");

        run_program(0);
        check_word(1, mult_add(m(64), m(65), m(66)));
        check_word(2, mult_sub(m(67), m(68), m(69)));
        check_word(3, mult_add(minus(m(70)), m(71), m(72)));
        check_word(4, mult_sub(minus(m(73)), m(74), m(75)));
        check_word(5, mult_add(sum(m(76), m(77)), m(78), zero));
        check_word(6, mult_add(sum(m(79), minus(m(80))), m(81), zero));
        check_word(7, mult_add(sum(m(82), minus(m(83))), m(84), m(83)));
        check_word(8, sum(sum(m(89), m(90)), m(91)));
        check_word(9, zero);

        if g_architecture = "fixed_mult_acc" then
            run_program(32);
            products := signed(m(85)) * signed(m(86)) + signed(m(87)) * signed(m(88))
                + shift_left(resize(signed(m(92)), 2*w), radix)
                + shift_left(resize(signed(m(93)), 2*w), radix);
            check_word(10, std_logic_vector(products(radix + w - 1 downto radix)));
        end if;

        y := m(96);
        for i in 1 to 100 loop
            y := mult_add(sum(m(97), minus(y)), m(98), y);
        end loop;
        run_program(64);
        check_word(96, y);

        if address_bits(g_instruction_width) >= 8 then
            run_program(96);
            check_word(250, mult_add(m(200), m(201), m(202)));
            check_word(251, mult_sub(m(203), m(204), m(205)));
        end if;

        test_runner_cleanup(runner);
        wait;
    end process stimulus;

    test_runner_watchdog(runner, 1 ms);

    capture_writes : process (clock) is
    begin
        if rising_edge(clock) then
            if mc_output.write_requested = '1' then
                data_ram(to_integer(mc_output.address)) <= mc_output.data;
            end if;
        end if;
    end process capture_writes;

    u_microprogram_core : entity work.microprogram_core
    generic map (g_program => test_program, g_data => program_data)
    port map (
        clock            => clock
        ,mproc_in        => mproc_in
        ,mproc_out       => mproc_out
        ,mc_output       => mc_output
        ,mc_write_in     => mc_write_in
        ,to_unit  => instr_in
        ,from_unit => instr_out
    );

    fixed_mult_add : if g_architecture = "fixed_mult_add" generate
        u_instruction : entity work.execution_unit(fixed_mult_add)
        generic map (g_radix => radix, g_pre_add_register => g_pre_add_register, g_product_register => g_product_register)
        port map (clock, instr_in, instr_out);
    end generate;

    fixed_mult_acc : if g_architecture = "fixed_mult_acc" generate
        u_instruction : entity work.execution_unit(fixed_mult_acc)
        generic map (g_radix => radix, g_pre_add_register => g_pre_add_register, g_product_register => g_product_register)
        port map (clock, instr_in, instr_out);
    end generate;

end vunit_simulation;
