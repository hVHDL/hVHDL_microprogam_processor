
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity generic_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of generic_processor_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    use work.real_to_fixed_pkg.all;
    package multiplier_pkg is new work.multiplier_generic_pkg generic map(32,1,1);
        use multiplier_pkg.all;

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => 10);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.ram_bit_width
        ,g_ram_depth_pow2 => 10);

    use mp_ram_pkg.all;

    signal ram_read_in : ram_read_in_array(0 to 4);
    signal ram_read_out : ram_read_out_array(ram_read_in'range);
    signal ram_write_in : ram_write_in_record;

    constant test_program : ram_array :=(
        7    => op(sub, 103, 101,102)
        ,8   => op(sub, 104, 102,101)
        ,101 => to_fixed(1.5, 32, 14)
        ,102 => to_fixed(0.5, 32, 14)

        , others => op(program_end));


    signal command : t_command :=(program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    function "and" (left, right : ram_write_in_record) return ram_write_in_record is
        variable retval : ram_write_in_record;
    begin
        retval.address := to_integer(
            to_unsigned(left.address, ram_depth_pow2)
         or to_unsigned(right.address, ram_depth_pow2));

        retval.data := left.data or right.data;

        retval.write_requested := left.write_requested or right.write_requested;

         return retval;
     end function;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        -- check(ram_was_read);
        -- check(last_ram_index_was_read, "last index was not read");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;

------------------------------------------------------------------------

    stimulus : process(simulator_clock)
        constant read_offset : natural := 57;
        alias inst_ram is ram_read_in(0);
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            init_mp_ram_read(ram_read_in);
            init_mp_write(ram_write_in);

            if simulation_counter < ram_array'high
            then
                request_data_from_ram(ram_read_in(4), simulation_counter);
            end if;

            if ram_read_is_ready(ram_read_out(4)) then
                command <= decode(get_ram_data(ram_read_out(4)));

                CASE decode(get_ram_data(ram_read_out(4))) is
                    WHEN sub =>
                        request_data_from_ram(ram_read_in(0)
                        , get_arg1(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(ram_read_in(1)
                        , get_arg2(get_ram_data(ram_read_out(4))));
                    WHEN others => -- do nothing
                end CASE;
            end if;

            CASE decode(instr_pipeline(2)) is
                WHEN sub =>
                    write_data_to_ram(ram_write_in, get_dest(instr_pipeline(2)), 
                        std_logic_vector(signed(get_ram_data(ram_read_out(0))) - signed(get_ram_data(ram_read_out(1)))));
                WHEN others => -- do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    make_pipeline : process(simulator_clock) is
    begin
        if rising_edge(simulator_clock) then
            instr_pipeline <= get_ram_data(ram_read_out(4)) 
                              & instr_pipeline(0 to instr_pipeline'high-1);
        end if;
    end process make_pipeline;
------------------------------------------------------------------------
    u_mpram : entity work.multi_port_ram
    generic map(mp_ram_pkg, test_program)
    port map(
        clock => simulator_clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);

------------------------------------------------------------------------
end vunit_simulation;
