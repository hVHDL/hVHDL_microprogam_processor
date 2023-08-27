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

    constant u : integer    := 1;
    constant y : integer    := 0;
    constant temp : integer := 2;
    constant g : integer    := 7;
    constant r0 : integer   := 0;
    constant r1 : integer   := 1;
    constant r2 : integer   := 2;
    constant r3 : integer   := 3;
    constant r4 : integer   := 4;
    constant r5 : integer   := 5;
    constant r6 : integer   := 6;
    constant r7 : integer   := 7;

    type program is array (natural range <>) of std_logic_vector(15 downto 0);
    subtype command_pipeline_array is program;

    signal executed_instruction : std_logic_vector(15 downto 0) := (others => '1');
    signal decoded_command : t_command := nop;

    type realarray is array (integer range 0 to 7) of real;
    signal registers : realarray := (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 0.1);

    signal result : real := 0.0;

    signal command_pipeline : program(0 to 7) := (others => (others => '0'));
------------------------------------------------------------------------
    constant test_program : program := (
        write_instruction(sub   , temp , u    , y)    ,
        write_instruction(mpy   , temp , temp , g)    ,
        write_instruction(add   , y    , y    , temp) ,
        write_instruction(ready , r0   , r0   , r1)   ,
        write_instruction(nop   , r0   , r0   , r1));

    signal mcode : program(test_program'range) := test_program;
    signal program_counter : natural := test_program'high;

    -- function is_ready
    -- return boolean
    -- is
    -- begin
    --     
    -- end is_ready;

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

            if simulation_counter mod 10 = 0 then
                program_counter <= 0;
            end if;

            if program_counter < mcode'high then
                program_counter <= program_counter + 1;
            end if;

            if program_counter < mcode'high then
                executed_instruction <= mcode(program_counter);
                decoded_command      <= decode(mcode(program_counter));
            end if;

            CASE decode(mcode(program_counter)) is
                when add =>
                    registers(get_dest(mcode(program_counter))) <= registers(get_arg1(mcode(program_counter))) + registers(get_arg2(mcode(program_counter)));
                when sub =>
                    registers(get_dest(mcode(program_counter))) <= registers(get_arg1(mcode(program_counter))) - registers(get_arg2(mcode(program_counter)));
                when mpy =>
                    registers(get_dest(mcode(program_counter))) <= registers(get_arg1(mcode(program_counter))) * registers(get_arg2(mcode(program_counter)));
                when mpy_add =>
                    registers(get_dest(mcode(program_counter))) <= registers(get_arg1(mcode(program_counter))) * registers(get_arg2(mcode(program_counter)));
                when div =>
                    registers(get_dest(mcode(program_counter))) <= registers(get_arg1(mcode(program_counter))) / registers(get_arg2(mcode(program_counter)));
                when ready => -- do nothing
                when nop   => --do nothing
            end CASE;

            command_pipeline(0) <= mcode(program_counter);
            for i in integer range 0 to command_pipeline'high-1 loop
                command_pipeline(i+1) <= command_pipeline(i);
            end loop;

            result <= registers(y);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
