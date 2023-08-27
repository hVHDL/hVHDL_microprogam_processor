LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.testprogram_pkg.all;

entity microprogram_execution_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of microprogram_execution_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal start_program : boolean := false;

    constant y    : integer := 0;
    constant u    : integer := 1;
    constant temp : integer := 2;
    constant g    : integer := 7;

    signal result : real := 0.0;

    -- alias include is "&" [program_array, program_array return program_array];

------------------------------------------------------------------------
    constant low_pass_filter : program_array := (
        write_instruction(sub         , temp , u    , y)    ,
        write_instruction(mpy         , temp , temp , g)    ,
        write_instruction(add         , y    , y    , temp) ,
        write_instruction(ready),
        write_instruction(program_end));
------------------------------------------------------------------------
    constant dummy : program_array := (
        write_instruction(nop),
        write_instruction(nop),
        write_instruction(nop),
        write_instruction(nop),
        write_instruction(nop),
        write_instruction(nop),
        write_instruction(program_end));
------------------------------------------------------------------------
    -- constant call_low_pass_filter : program_array := (
    --     write_instruction(jump, ),
        -- write_instruction(program_end));
    constant test_program : program_array := dummy & low_pass_filter;

    signal mcode : program_array(test_program'range) := test_program;

    signal program_counter : natural := test_program'high;
    signal registers : realarray := (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 0.1);

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

        procedure request_low_pass_filter is
        begin
            program_counter <= dummy'length;
        end request_low_pass_filter;


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;


            create_processor(program_counter , mcode(program_counter) , registers);
            if simulation_counter = 10 or decode(mcode(program_counter)) = ready then
                request_low_pass_filter;
            end if;

            -- command_pipeline(0) <= mcode(program_counter);
            -- for i in integer range 0 to command_pipeline'high-1 loop
            --     command_pipeline(i+1) <= command_pipeline(i);
            -- end loop;
            result <= registers(y);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
