
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


    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    use work.real_to_fixed_pkg.all;

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => 6);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.ram_bit_width
        ,g_ram_depth_pow2 => 10);
        use mp_ram_pkg.all;

    signal output1 : signed(31 downto 0) := (others => '0');
    signal o1_ready : boolean := false;
    signal test1 : real := 0.0;

    constant used_radix : natural := 20;

    constant test_program : ram_array :=(
        6   => op(sub, 96, 101,101)
        , 7  => op(sub     , 100 , 101 , 102)
        , 8  => op(sub     , 99  , 102 , 101)
        , 9  => op(add     , 98  , 103 , 104)
        , 10 => op(add     , 97  , 104 , 103)
        , 11 => op(mpy_add , 96  , 101 , 104  , 105)
        , 12 => op(mpy_add , 95  , 102 , 104  , 102)
        , 13 => op(program_end)

        , 16 => op(sub, 96, 101,101)
        , 17 => op(sub     , 100 , 101 , 102)
        , 18 => op(sub     , 99  , 102 , 101)
        , 19 => op(add     , 98  , 103 , 104)
        , 20 => op(add     , 97  , 104 , 103)
        , 21 => op(mpy_add , 96  , 101 , 104  , 105)
        , 22 => op(mpy_add , 95  , 102 , 104  , 102)
        , 23 => op(program_end)

        , 101 => to_fixed(1.5   , 32 , used_radix)
        , 102 => to_fixed(0.5   , 32 , used_radix)
        , 103 => to_fixed(-2.5  , 32 , used_radix)
        , 104 => to_fixed(-0.65 , 32 , used_radix)
        , 105 => to_fixed(-1.0  , 32 , used_radix)

        , others => op(nop));

    signal calculate : boolean := false;
    signal start_address : natural := 6;

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
                test1 <= to_real(output1, used_radix);
            end if;

            calculate <= false;
            CASE simulation_counter is
                WHEN 5 =>
                    calculate <= true;
                    start_address <= 22;
                WHEN 25 =>
                    calculate <= true;
                    start_address <= 8;
                WHEN others => -- do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_microprogram_processor : entity work.microprogram_processor
    generic map(microinstruction_pkg, mp_ram_pkg, used_radix, test_program)
    port map(simulator_clock, calculate, start_address, output1, o1_ready);
------------------------------------------------------------------------
end vunit_simulation;
