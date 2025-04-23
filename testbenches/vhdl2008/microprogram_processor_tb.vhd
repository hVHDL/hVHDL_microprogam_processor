
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

    constant y : natural := 5;
    constant u : natural := 17;
    constant g : natural := 16;

    constant program_data : ram_array :=(
          11 => to_fixed(1.5   , 32 , used_radix)

        , 12 => to_fixed(0.5        , 32 , used_radix)
        , 13 => to_fixed(-2.5       , 32 , used_radix)
        , 14 => to_fixed(-0.65      , 32 , used_radix)
        , 15 => to_fixed(-1.0       , 32 , used_radix)
        , 16 => to_fixed(1.0/7.6359 , 32 , used_radix)
        , u => to_fixed(20.0 , 32 , used_radix)
        , others => (others => '0')
    );

    constant test_program : ram_array :=(
        6   => op(sub, 6, 11,11)
        , 7  => op(sub     , 10 , 11 , 12)
        , 8  => op(sub     , 9  , 12 , 11)
        , 9  => op(add     , 8  , 13 , 14)
        , 10 => op(add     , 7  , 14 , 13)
        , 11 => op(mpy_add , 6  , 11 , 14  , 15)
        , 13 => op(program_end)

        , 16 => op(sub          , 6  , 11 , 11)
        , 17 => op(sub          , 10 , 11 , 12)
        , 18 => op(sub          , 9  , 12 , 11)
        , 19 => op(add          , 8  , 13 , 14)
        , 20 => op(add          , 7  , 14 , 13)
        , 21 => op(mpy_add      , 6  , 11 , 14  , 15)
        , 23 => op(program_end)

        , 25 => op(set_rpt, 100)
        , 26 => op(a_sub_b_mpy_c , y,  u , y , g)
        , 30 => op(jump, 26)
        , 35 => op(program_end)

        , others => op(nop));

    signal calculate     : boolean := false;
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

                WHEN 50 =>
                    calculate <= true;
                    start_address <= 25;
                WHEN others => -- do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_microprogram_processor : entity work.microprogram_processor
    generic map(microinstruction_pkg, mp_ram_pkg, used_radix, test_program, program_data)
    port map(simulator_clock, calculate, start_address, output1, o1_ready);
------------------------------------------------------------------------
end vunit_simulation;
