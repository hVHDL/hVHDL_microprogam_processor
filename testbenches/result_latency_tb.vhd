LIBRARY ieee  ;
    USE ieee.NUMERIC_STD.all  ;
    USE ieee.std_logic_1164.all  ;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.all;

-- measures how many instructions after an instruction the first one that
-- reads its result can be : programs k = 1..20 issue
--
--   mpy_add 70+k <- 64 * 65 + 66
--   k instructions later : mpy_add 100+k <- (70+k) * 67 + 68
--
-- and the data ram's ports give the clock the first result is written and
-- the clock the second instruction reads it. The read port and the write
-- port are separate ram ports, a read in the clock of the write is a port
-- collision, so the latency is the smallest k with the read after the
-- write. The results must be right from that k up, and the latency must
-- be what execution_unit_pkg's fixed_point_result_latency() says.
entity result_latency_tb is
  generic (
      runner_cfg : string
      ;g_architecture     : string  := "fixed_mult_add"
      ;g_pre_add_register : boolean := false
      ;g_product_register : boolean := false
  );
end;

architecture vunit_simulation of result_latency_tb is

    constant clock_period : time := 1 ns;
    signal clock : std_logic := '0';
    signal clock_count : natural := 0;

    constant radix : natural := 20;
    constant max_k : natural := 20;

    constant ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 3, datawidth => 32, addresswidth => 10);
    constant instr_ref_subtype : subtype_ref_record :=
        create_ref_subtypes(readports => 1, datawidth => 32, addresswidth => 10);

    subtype word is std_logic_vector(31 downto 0);
    type word_array is array (natural range <>) of word;

    function make_data return work.dual_port_ram_pkg.ram_array is
        variable retval : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(31 downto 0)
            := (others => (others => '0'));
    begin
        retval(64) := std_logic_vector(to_signed( 3 * 2**radix / 2, 32)); --  1.5
        retval(65) := std_logic_vector(to_signed(-5 * 2**radix / 4, 32)); -- -1.25
        retval(66) := std_logic_vector(to_signed( 7 * 2**radix / 8, 32)); --  0.875
        retval(67) := std_logic_vector(to_signed( 9 * 2**radix / 4, 32)); --  2.25
        retval(68) := std_logic_vector(to_signed(-1 * 2**radix / 2, 32)); -- -0.5
        return retval;
    end make_data;

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(31 downto 0) := make_data;

    function make_program return microprogram is
        variable retval : microprogram(0 to instr_ref_subtype.address_high) := (others => mi(nop));
    begin
        for k in 1 to max_k loop
            retval(32*k)         := mi(mpy_add, 70 + k, 64, 65, 66);
            retval(32*k + k)     := mi(mpy_add, 100 + k, 70 + k, 67, 68);
            retval(32*k + k + 1) := mi(program_end);
        end loop;
        return retval;
    end make_program;

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(31 downto 0)
        := encode(make_program, 32);

    signal mproc_in  : microprogram_processor_in_record := (processor_requested => false, start_address => 0);
    signal mproc_out : microprogram_processor_out_record;

    signal mc_output   : ref_subtype.ram_write_in'subtype;
    signal mc_write_in : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    use work.execution_unit_pkg.all;
    constant unit_in_ref : execution_unit_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to 12 => op(nop))
    );
    constant unit_out_ref : execution_unit_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
    );

    signal unit_in  : unit_in_ref'subtype  := unit_in_ref;
    signal unit_out : unit_out_ref'subtype := unit_out_ref;

    signal data_ram : word_array(0 to ref_subtype.address_high) := (others => (others => '0'));

    -- the clock each address was last written, and last read, at the ram
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
            wait until rising_edge(clock) and is_ready(mproc_out) for 10 us;
            check(is_ready(mproc_out), "program " & integer'image(start) & " did not finish");
            for i in 1 to 20 loop
                wait until rising_edge(clock);
            end loop;
        end run_program;

        function mult_add (a, b, c : word) return word is
            variable result : signed(63 downto 0);
        begin
            result := signed(a) * signed(b) + shift_left(resize(signed(c), 64), radix);
            return std_logic_vector(result(radix + 31 downto radix));
        end mult_add;

        constant first  : word := mult_add(program_data(64), program_data(65), program_data(66));
        constant second : word := mult_add(first, program_data(67), program_data(68));

        variable latency       : integer := -1;
        variable first_correct : integer := -1;
        variable read_after_write : boolean;

    begin
        test_runner_setup(runner, runner_cfg);

        for k in 1 to max_k loop
            run_program(32*k);
            check_equal(data_ram(70 + k), first, "first result, k = " & integer'image(k));
            read_after_write := read_clock(70 + k) > write_clock(70 + k);
            if read_after_write and latency < 0 then
                latency := k;
            end if;
            if data_ram(100 + k) = second and first_correct < 0 then
                first_correct := k;
            end if;
            if latency > 0 then
                check_equal(data_ram(100 + k), second, "dependent result, k = " & integer'image(k));
            end if;
            info("k = " & integer'image(k)
                & " : written at clock " & integer'image(write_clock(70 + k))
                & ", read at clock " & integer'image(read_clock(70 + k))
                & ", dependent result " & boolean'image(data_ram(100 + k) = second));
        end loop;

        info(g_architecture & ", pre-adder register " & boolean'image(g_pre_add_register)
            & ", product register " & boolean'image(g_product_register)
            & " : result latency " & integer'image(latency)
            & ", right results from " & integer'image(first_correct));
        check(latency > 0, "no read after the write within " & integer'image(max_k) & " instructions");
        check_equal(latency, fixed_point_result_latency(g_pre_add_register, g_product_register),
            "fixed_point_result_latency()");

        test_runner_cleanup(runner);
        wait;
    end process stimulus;

    test_runner_watchdog(runner, 1 ms);

    count_clocks : process (clock) is
    begin
        if rising_edge(clock) then
            clock_count <= clock_count + 1;
        end if;
    end process count_clocks;

    -- the ram's ports : the execution unit's read requests and the core's
    -- write, as the ram samples them on this edge
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
            end if;
        end if;
    end process watch_ram;

    u_microprogram_core : entity work.microprogram_core
    generic map (g_program => test_program, g_data => program_data)
    port map (
        clock      => clock
        ,mproc_in  => mproc_in
        ,mproc_out => mproc_out
        ,mc_output => mc_output
        ,mc_write_in => mc_write_in
        ,to_unit   => unit_in
        ,from_unit => unit_out
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
