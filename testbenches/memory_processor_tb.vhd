LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.float_example_program_pkg.all;
    use work.memory_processor_pkg.all;
    use work.float_to_real_conversions_pkg.all;

entity memory_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of memory_processor_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 10e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    ------------------------------------------------------------------------

    constant u_address : natural := 80;
    constant y_address : natural := 90;
    constant g_address : natural := 100;
    constant temp_address : natural := 110;

    constant ram_contents : ram_array := build_nmp_sw(0.05 , u_address , y_address , g_address, temp_address);

    signal self_data_in : memory_processor_data_in_record := init_memory_processor_data_in;
    signal self_data_out : memory_processor_data_out_record;

    signal ram_was_ready : boolean := false;

    signal counter : natural range 0 to 7  := 7;
    signal counter2 : natural range 0 to 7 := 7;

    signal result1 : real := 0.0;
    signal result2 : real := 0.0;
    signal result3 : real := 0.0;

    signal testi1 : real := 0.0;
    signal testi2 : real := 0.0;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(ram_was_ready, "ram was not read");
        check(result3 > 0.45 and result3 < 0.55);
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            init_memory_processor(self_data_in);

            ------------------------------------------------------------------------
            -- test signals
            ------------------------------------------------------------------------
            if simulation_counter mod 60 = 0 then
                request_processor(self_data_in);
            end if;
            if program_is_ready(self_data_out) then
                counter <= 0;
                counter2 <= 0;
            end if;
            if counter < 7 then
                counter <= counter +1;
            end if;

            CASE counter is
                WHEN 0 => request_data_from_ram(self_data_in, y_address+7);
                WHEN others => --do nothing
            end CASE;

            if ram_read_is_ready(self_data_out) then
                counter2 <= counter2 + 1;
                CASE counter2 is
                    WHEN 0 => result3 <= to_real(to_float(get_ram_data(self_data_out)));
                    WHEN others => -- do nothing
                end CASE; --counter2
            end if;

            ram_was_ready <= ram_was_ready or ram_read_is_ready(self_data_out);

        end if; -- rising_edge
    end process stimulus;	

------------------------------------------------------------------------
    u_memory_processor : entity work.memory_processor
    generic map(ram_contents)
    port map(simulator_clock, self_data_in, self_data_out);

------------------------------------------------------------------------
end vunit_simulation;
