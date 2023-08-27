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

    type program_array is array (natural range <>) of std_logic_vector(15 downto 0);
    subtype command_pipeline_array is program_array;

    signal result : real := 0.0;

------------------------------------------------------------------------
    constant test_program : program_array := (
        write_instruction(sub         , temp , u    , y)    ,
        write_instruction(mpy         , temp , temp , g)    ,
        write_instruction(add         , y    , y    , temp) ,
        write_instruction(ready       , r0   , r0   , r1)   ,
        write_instruction(program_end , r0   , r0   , r1));

    signal mcode : program_array(test_program'range) := test_program;

    type realarray is array (integer range 0 to 7) of real;

    signal program_counter : natural := test_program'high;
    signal registers : realarray := (0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 0.1);

    -- function is_ready
    -- return boolean
    -- is
    -- begin
    --     
    -- end is_ready;
    -- signal command_pipeline : program_array(0 to 7) := (others => (others => '0'));

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

        procedure create_alu
        (
            signal pgm_counter : inout natural;
            instruction : in std_logic_vector;
            signal reg  : inout realarray
        )
        is
        begin
            if decode(instruction) /= program_end then
                pgm_counter <= pgm_counter + 1;
            end if;
            CASE decode(instruction) is
                when add =>
                    reg(get_dest(instruction)) <= reg(get_arg1(instruction)) + reg(get_arg2(instruction));
                when sub =>
                    reg(get_dest(instruction)) <= reg(get_arg1(instruction)) - reg(get_arg2(instruction));
                when mpy =>
                    reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction));
                when mpy_add =>
                    reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction));
                when div =>
                    reg(get_dest(instruction)) <= reg(get_arg1(instruction)) / reg(get_arg2(instruction));
                when program_end =>
                when ready => -- do nothing
                when nop   => --do nothing
            end CASE;
            
        end create_alu;

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            if simulation_counter mod 10 = 0 then
                program_counter <= 0;
            end if;

            create_alu(program_counter , mcode(program_counter) , registers);

            -- command_pipeline(0) <= mcode(program_counter);
            -- for i in integer range 0 to command_pipeline'high-1 loop
            --     command_pipeline(i+1) <= command_pipeline(i);
            -- end loop;
            result <= registers(y);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
