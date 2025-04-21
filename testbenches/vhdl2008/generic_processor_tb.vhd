LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

entity microprogram_sequencer is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
        ;package mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
        ;arg1_mem : natural := 1
        ;arg2_mem : natural := 2
        ;arg3_mem : natural := 3
        ;inst_mem : natural := 4
        ;radix    : natural := 14
       );
    port(
        clock : in std_logic
        ;ram_read_in  : out mp_ram_pkg.ram_read_in_array
        ;ram_read_out : in mp_ram_pkg.ram_read_out_array
        ;ram_write_in : out mp_ram_pkg.ram_write_in_record
        ;processor_enabled : out boolean := true
    );
    use microinstruction_pkg.all;
    use mp_ram_pkg.all;
    use work.real_to_fixed_pkg.all;
end;


architecture rtl of microprogram_sequencer is

    -- signal processor_enabled : boolean := true;
    signal program_counter   : natural range 0 to 1023 := 0;

begin

    make_program_counter : process(clock)
    begin
        if rising_edge(clock) then
            init_mp_ram_read(ram_read_in);
            init_mp_write(ram_write_in);

            if processor_enabled
            then
                if program_counter >= 150
                then
                    processor_enabled <= false;
                else
                    program_counter <= program_counter + 1;
                    request_data_from_ram(ram_read_in(0), program_counter);
                end if;
            end if;

        end if; -- rising_edge
    end process make_program_counter;	
    -----

end rtl;
---------------------------------------------
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

    constant used_radix : natural := 14;

    constant test_program : ram_array :=(
        6   => op(sub, 96, 101,101)

        , 7  => op(sub     , 100 , 101 , 102)
        , 8  => op(sub     , 99  , 102 , 101)
        , 9  => op(add     , 98  , 103 , 104)
        , 10 => op(add     , 97  , 104 , 103)
        , 11 => op(mpy_add , 96  , 101 , 104  , 105)
        , 12 => op(mpy_add , 95  , 102 , 104  , 102)

        , 101 => to_fixed(1.5  , 32 , used_radix)
        , 102 => to_fixed(0.5  , 32 , used_radix)
        , 103 => to_fixed(-1.5 , 32 , used_radix)
        , 104 => to_fixed(-0.5 , 32 , used_radix)
        , 105 => to_fixed(-1.0 , 32 , used_radix)

        , others => op(program_end));


    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    signal pim_ram_write     : ram_write_in_record;
    signal add_sub_ram_write : ram_write_in_record;

    --
    --
    signal processor_enabled : boolean := true;

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
        if ram_read_is_ready(ram_read_out(0)) then
            command <= decode(get_ram_data(ram_read_out(0)));
        end if;
    end process debug;
------------------------------------------------------------------------
------------------------------------------------------------------------
    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
        end if; -- rising_edge
    end process stimulus;	
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(microinstruction_pkg, mp_ram_pkg, inst_mem => 0, radix => used_radix)
    port map(simulator_clock , pim_read_in , ram_read_out , pim_ram_write , processor_enabled);
----------------------------------------------------------
    make_pipeline : process(simulator_clock) is
    begin
        if rising_edge(simulator_clock) then

            instr_pipeline <= op(nop) & instr_pipeline(0 to instr_pipeline'high-1);

            if processor_enabled 
            then
                instr_pipeline(0) <= get_ram_data(ram_read_out(0));
            end if;

        end if;
    end process make_pipeline;
------------------------------------------------------------------------
------------------------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(microinstruction_pkg, mp_ram_pkg, inst_mem => 0, radix => used_radix)
    port map(simulator_clock , sub_read_in , ram_read_out , add_sub_ram_write , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
    ram_read_in  <= pim_read_in   and sub_read_in;
    ram_write_in <= pim_ram_write and add_sub_ram_write;

    u_mpram : entity work.multi_port_ram
    generic map(mp_ram_pkg, test_program)
    port map(
        clock => simulator_clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);
------------------------------------------------------------------------
end vunit_simulation;
