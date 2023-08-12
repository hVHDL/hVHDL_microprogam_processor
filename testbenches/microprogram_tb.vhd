LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity microprogram_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of microprogram_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 50;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    function execute
    (
        arg1, arg2 : real;
        command : natural range 0 to 3
    )
    return real 
    is
        variable retval : real := 0.0;
    begin
        CASE command is
            WHEN 0 => retval := arg1 + arg2;
            WHEN 1 => retval := arg1 - arg2;
            WHEN 2 => retval := arg1 * arg2;
            WHEN 3 => retval := arg1 / arg2;
        end CASE;

        return retval;
    end execute;

    type realarray is array (integer range 0 to 7) of real;
    signal reg : realarray := (others => 0.0);


    signal program_counter : natural := 7;
    signal acc : real := 0.0;
    signal u : real;
    signal y : real := 0.0;
    signal g : real := 0.1;

    signal is_ready : boolean := false;

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

        procedure sum
        (
            signal r : out real;
            a, b : real
        ) is
        begin
            r <= a + b;
        end sum;

        procedure subs
        (
            signal r : out real;
            a, b : real
        ) is
        begin
            r <= a - b;
        end subs;

        procedure mpy
        (
            signal r : out real;
            a,b : real
        ) is
        begin
            r <= execute(a,b,2);
        end mpy;

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            is_ready <= false;
            if program_counter < 2 then
                program_counter <= program_counter + 1;
            end if;

            if program_counter = 2 then
                is_ready <= true;
            end if;
            CASE program_counter is
                WHEN 0 => subs(acc, u, y);
                WHEN 1 => mpy(reg(0), acc, g);
                WHEN 2 => sum(y,y,reg(0));
                when others => --halt and wait;
            end CASE;


            if simulation_counter = 10 or is_ready then
                program_counter <= 0;
                u <= 1.0;
            end if;
        -- assembly program for y = (y-u)*g;
            /*
            subs r1 , y    , u;
            mpy r1  , g
            sum y   , diff
            */



        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
