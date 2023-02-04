LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity test_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of test_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 50;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal a,b,c : integer := 0;

    subtype int4 is integer range 0 to 2**4-1;
    type processor_command_record is record
        command : int4;
        data1 : integer;
        data2 : integer;
        data3 : integer;
    end record;
    constant init_pipeline : processor_command_record := (0,0,0,0);
    type processor_pipeline_array is array (integer range 0 to 7) of processor_command_record;
    signal processor_pipeline : processor_pipeline_array := (others => init_pipeline);

    function get_command
    (
        pipeline_stage : processor_command_record
    )
    return integer
    is
    begin
        return pipeline_stage.command;
    end get_command;

    constant add_requested : integer := 1;

    type int_array is array (integer range <>) of integer;
    signal memory : int_array(0 to 7) := (others => 0);

    constant add_results : int_array := (15, -8, 0);
    signal results_index : integer := 0;

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

            c <= a + b;

            -- processor_pipeline <= processor_pipeline(0 to processor_pipeline'high-1) & init_pipeline;
            processor_pipeline(0) <= init_pipeline;
            processor_pipeline(1) <= processor_pipeline(0);
            processor_pipeline(2) <= processor_pipeline(1);
            processor_pipeline(3) <= processor_pipeline(2);
            processor_pipeline(4) <= processor_pipeline(3);
            processor_pipeline(5) <= processor_pipeline(4);
            processor_pipeline(6) <= processor_pipeline(5);
            processor_pipeline(7) <= processor_pipeline(6);


            if get_command(processor_pipeline(0)) = add_requested then
                a <= processor_pipeline(0).data1;
                b <= processor_pipeline(0).data2;
            end if;

            if get_command(processor_pipeline(2)) = add_requested then
                processor_pipeline(3).data3 <= c;
                if results_index < add_results'high then
                    results_index <= results_index + 1;
                    check(c = add_results(results_index), "expected " & integer'image(add_results(results_index)) & " got " & integer'image(c));
                end if;
            end if;

            CASE simulation_counter is
                WHEN 5 => processor_pipeline(0) <= (command => add_requested, data1 => 10, data2 => 5, data3 => -1);
                WHEN 6 => processor_pipeline(0) <= (command => add_requested, data1 => -10, data2 => 2, data3 => -1);
                -- WHEN 6 => processor_pipeline(0) <= (command => add_requested, data1 => -1, data2 => 5, data3 => -1);
                when others => -- do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
