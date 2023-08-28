LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.testprogram_pkg.all;

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
    function get_low_pass_filter return program_array
    is
        constant y    : integer := 0;
        constant u    : integer := 1;
        constant temp : integer := 2;
        constant g    : integer := 7;

        variable returned_code : program_array(0 to 4);
    begin
        returned_code := (
            write_instruction(sub    , temp , u    , y)    ,
            write_instruction(mpy    , temp , temp , g)    ,
            write_instruction(add    , y    , y    , temp) ,
            write_instruction(ready) ,
            write_instruction(program_end)
        );

        return returned_code;
        
    end get_low_pass_filter;

------------------------------------------------------------------------
    function get_sos_filter return program_array
    is
        constant y  : integer := 0;
        constant u  : integer := 1;
        constant x1 : integer := 2;
        constant x2 : integer := 3;
        constant b0 : integer := 4;
        constant b1 : integer := 5;
        constant b2 : integer := 6;
        constant a1 : integer := 7;
        constant a2 : integer := 8;

        constant sos_program : program_array := (
            write_instruction(mpy_add , y  , b0 , u   , x1) ,
            write_instruction(mpy_add , x1 , b1 , u   , x2) ,
            write_instruction(mpy     , x2 , b2 , u ) ,
            write_instruction(mpy_add , x1 , a1 , y   , x1) ,
            write_instruction(mpy_add , x2 , a2 , y   , x2) ,
            write_instruction(ready)  ,
            write_instruction(program_end)
        );
        variable returned_code : program_array(0 to 6);
    begin

        returned_code := sos_program;
        
        return returned_code;
    end get_sos_filter;

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
    constant low_pass_filter : program_array := get_low_pass_filter;
    constant sos : program_array := get_sos_filter;

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
