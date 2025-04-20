
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity generic_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of generic_processor_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    use work.real_to_fixed_pkg.all;
    package multiplier_pkg is new work.multiplier_generic_pkg generic map(32,1,1);
        use multiplier_pkg.all;

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => 10);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.ram_bit_width
        ,g_ram_depth_pow2 => 10);

    use mp_ram_pkg.all;

    signal ram_read_in  : ram_read_in_array(0 to 4);

    signal pim_read_in  : ram_read_in_array(0 to 4);
    signal sub_read_in  : ram_read_in_array(0 to 4);

    signal ram_read_out : ram_read_out_array(ram_read_in'range);
    signal ram_write_in : ram_write_in_record;

    constant test_program : ram_array :=(
        6   => op(sub, 96, 101,101)

        , 7  => op(sub , 100 , 101 , 102)
        , 8  => op(sub , 99  , 102 , 101)
        , 9  => op(add , 98  , 103 , 104)
        , 10 => op(add , 97  , 104 , 103)

        , 101 => to_fixed(1.5  , 32 , 14)
        , 102 => to_fixed(0.5  , 32 , 14)
        , 103 => to_fixed(-1.5 , 32 , 14)
        , 104 => to_fixed(-0.5 , 32 , 14)

        , others => op(program_end));


    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    signal pim_ram_write     : ram_write_in_record;
    signal add_sub_ram_write : ram_write_in_record;


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
    debug : process(all) is
    begin
        if ram_read_is_ready(ram_read_out(4)) then
            command <= decode(get_ram_data(ram_read_out(4)));
        end if;
    end process debug;
------------------------------------------------------------------------
    stimulus : process(simulator_clock)
        constant read_offset : natural := 57;
        alias inst_ram is ram_read_in(0);
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            init_mp_ram_read(pim_read_in);
            init_mp_write(pim_ram_write);

            if simulation_counter < ram_array'high
            then
                request_data_from_ram(pim_read_in(4), simulation_counter);
            end if;

        end if; -- rising_edge
    end process stimulus;	
    -----
    make_pipeline : process(simulator_clock) is
    begin
        if rising_edge(simulator_clock) then
            instr_pipeline <= get_ram_data(ram_read_out(4)) 
                              & instr_pipeline(0 to instr_pipeline'high-1);
        end if;
    end process make_pipeline;
    -----
------------------------------------------------------------------------
------------------------------------------------------------------------
    add_sub : process(simulator_clock) is
    begin
        if rising_edge(simulator_clock) then
            init_mp_ram_read(sub_read_in);
            init_mp_write(add_sub_ram_write);

            ---------------
            if ram_read_is_ready(ram_read_out(4)) then
                CASE decode(get_ram_data(ram_read_out(4))) is
                    WHEN add =>
                        request_data_from_ram(sub_read_in(0)
                        , get_arg1(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(sub_read_in(1)
                        , get_arg2(get_ram_data(ram_read_out(4))));

                    WHEN sub =>
                        request_data_from_ram(sub_read_in(0)
                        , get_arg1(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(sub_read_in(1)
                        , get_arg2(get_ram_data(ram_read_out(4))));
                    WHEN others => -- do nothing
                end CASE;
            end if;
            ---------------
            CASE decode(instr_pipeline(2)) is
                WHEN add =>
                    write_data_to_ram(add_sub_ram_write, get_dest(instr_pipeline(2)), 
                        std_logic_vector(signed(get_ram_data(ram_read_out(0))) + signed(get_ram_data(ram_read_out(1)))));
                WHEN sub =>
                    write_data_to_ram(add_sub_ram_write, get_dest(instr_pipeline(2)), 
                        std_logic_vector(signed(get_ram_data(ram_read_out(0))) - signed(get_ram_data(ram_read_out(1)))));
                WHEN others => -- do nothing
            end CASE;
            ---------------
        end if;
    end process add_sub;
------------------------------------------------------------------------
    ram_read_in <= pim_read_in and sub_read_in;
    ram_write_in <= pim_ram_write and add_sub_ram_write ;

    u_mpram : entity work.multi_port_ram
    generic map(mp_ram_pkg, test_program)
    port map(
        clock => simulator_clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);

------------------------------------------------------------------------
end vunit_simulation;
