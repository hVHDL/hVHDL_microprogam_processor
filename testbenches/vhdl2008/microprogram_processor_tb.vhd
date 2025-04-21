
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity microprogram_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of microprogram_processor_tb is

    use work.real_to_fixed_pkg.all;

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    signal calculate : boolean := false;
    signal start_address : natural := 6;
    signal output1 : signed(31 downto 0) := (others => '0');
    signal o1_ready : boolean := false;
    signal test1 : real := 0.0;
begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------
    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            if o1_ready then
                test1 <= to_real(output1, 14);
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_microprogram_processor : entity work.microprogram_processor
    port map(simulator_clock, calculate, start_address, output1, o1_ready);
------------------------------------------------------------------------
end vunit_simulation;
