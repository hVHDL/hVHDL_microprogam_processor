LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.testprogram_pkg.all;
    use work.test_programs_pkg.all;

entity test_w_two_filters_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of test_w_two_filters_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
------------------------------------------------------------------------
    constant low_pass_filter : program_array := get_low_pass_filter;
    constant sos : program_array := get_sos_filter;
    constant dummy : program_array := get_dummy;

    constant test_program : program_array := dummy & low_pass_filter & sos;

    signal mcode : program_array(test_program'range) := test_program;

    signal program_counter : natural := test_program'high;
    signal registers       : realarray := (0.0 , 1.0 , 2.0 , 3.0 , 4.0 , 5.0 , 6.0 , 0.1  , 0.0);
    signal register_cache  : realarray := (0.0 , 1.0 , 2.0 , 3.0 , 4.0 , 5.0 , 6.0 , 0.3 , 0.0);
    signal result1         : real := 0.0;
    signal result2         : real := 0.0;

    signal filter_sel : natural := 1;

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
    ------------------------------
        procedure request_low_pass_filter is
        begin
            program_counter <= dummy'length;
        end request_low_pass_filter;
    ------------------------------
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;


            create_processor(program_counter , mcode(program_counter) , registers);
            if simulation_counter = 10 then
                request_low_pass_filter;
            end if;

            if decode(mcode(program_counter)) = ready then
                request_low_pass_filter;
                registers <= register_cache;
                register_cache <= registers;
                if filter_sel = 1 then
                    filter_sel <= 2;
                    result1 <= registers(0);
                else
                    filter_sel <= 1;
                    result2 <= registers(0);
                end if;
            end if;

            -- command_pipeline(0) <= mcode(program_counter);
            -- for i in integer range 0 to command_pipeline'high-1 loop
            --     command_pipeline(i+1) <= command_pipeline(i);
            -- end loop;


        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
