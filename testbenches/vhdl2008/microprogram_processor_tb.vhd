
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

    signal test1 : real := 0.0;
    signal test2 : real := 0.0;
    signal test3 : real := 0.0;
    signal test4 : real := 0.0;
    signal test5 : real := 0.0;

    constant used_radix : natural := 20;

    constant y : natural := 50;
    constant u : natural := 60;
    constant uext : natural := 120;
    constant g : natural := 70;

    constant program_data : ram_array :=(
          11 => to_fixed(1.5   , 32 , used_radix)

        , 12  => to_fixed(0.5        , 32 , used_radix)
        , 13  => to_fixed(-2.5       , 32 , used_radix)
        , 14  => to_fixed(-0.65      , 32 , used_radix)
        , 15  => to_fixed(-1.0       , 32 , used_radix)
        , g   => to_fixed(1.0/20.6359 , 32 , used_radix)
        , g+1 => to_fixed(1.0/6.6359 , 32 , used_radix)
        , g+2 => to_fixed(1.0/5.6359 , 32 , used_radix)
        , g+3 => to_fixed(1.0/4.6359 , 32 , used_radix)
        , g+4 => to_fixed(1.0/3.6359 , 32 , used_radix)
        , u   => to_fixed(20.0       , 32 , used_radix)
        , u+1 => to_fixed(7.0        , 32 , used_radix)
        , u+2 => to_fixed(39.0       , 32 , used_radix)
        , u+3 => to_fixed(1.0        , 32 , used_radix)
        , u+4 => to_fixed(9.0        , 32 , used_radix)
        , y   => to_fixed(0.0        , 32 , used_radix)
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

        , 25 => op(set_rpt, 200)

        , 26 => op(a_sub_b_mpy_c , y   , u, y   , g)
        , 27 => op(a_sub_b_mpy_c , y+1 , u+1, y+1 , g+1)
        , 28 => op(jump, 26)
        , 29 => op(a_sub_b_mpy_c , y+2 , uext, y+2 , g+2)
        , 30 => op(a_sub_b_mpy_c , y+3 , u+3, y+3 , g+3)
        , 31 => op(a_sub_b_mpy_c , y+4 , u+4, y+4 , g+4)

        , 35 => op(program_end)

        , others => op(nop));

    signal calculate     : boolean := false;
    signal start_address : natural := 6;


    function generic_op 
        generic (
            type t_lista
            ;function get_pos(a : t_lista) return natural is <>
        )
        parameter (x : t_lista) return natural is
    begin
        return get_pos(x);
    end generic_op;

    type test_list is (eka, toka, kolmas, neljas);
    function ttt(a : test_list) return natural is
    begin
        return test_list'pos(a);
    end ttt;

    function op is new generic_op generic map(t_lista => test_list, get_pos => ttt);
    ----
    signal mc_read_in  : ram_read_in_array(0 to 3);
    signal mc_read_out : ram_read_out_array(0 to 3);
    signal mc_output   : ram_write_in_record;
    ----
    signal mc_read_in_buf  : ram_read_in_array(0 to 3);
    signal mc_read_out_buf : ram_read_out_array(0 to 3);

    signal testisignaali : boolean := false;

    signal ext_input : std_logic_vector(31 downto 0) := to_fixed(-22.351, 32, used_radix);

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
            if write_requested(mc_output,50) then
                test1 <= to_real(signed(get_data(mc_output)), used_radix);
            end if;
            if write_requested(mc_output,51) then
                test2 <= to_real(signed(get_data(mc_output)), used_radix);
            end if;
            if write_requested(mc_output,52) then
                test3 <= to_real(signed(get_data(mc_output)), used_radix);
            end if;
            if write_requested(mc_output,53) then
                test4 <= to_real(signed(get_data(mc_output)), used_radix);
            end if;
            if write_requested(mc_output,54) then
                test5 <= to_real(signed(get_data(mc_output)), used_radix);
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

            for i in mc_read_in'range loop
                if read_requested(mc_read_in(i), 120) then
                    mc_read_out_buf(i).data <= ext_input;
                    mc_read_out_buf(i).data_is_ready <= '1';
                    testisignaali <= not testisignaali;
                else
                    mc_read_out_buf(i).data <= (others => '0');
                    mc_read_out_buf(i).data_is_ready <= '0';
                end if;
            end loop;

            mc_read_out <= mc_read_out_buf;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------

    u_microprogram_processor : entity work.microprogram_processor
    generic map(microinstruction_pkg, mp_ram_pkg, used_radix, test_program, program_data)
    port map(simulator_clock, calculate, start_address, mc_read_in, mc_read_out, mc_output);
------------------------------------------------------------------------
end vunit_simulation;
