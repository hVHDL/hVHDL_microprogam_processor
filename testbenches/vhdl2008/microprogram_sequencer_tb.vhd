LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity microprogram_sequencer_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of microprogram_sequencer_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    use work.real_to_fixed_pkg.all;
    use work.microinstruction_pkg.all;

    use work.multi_port_ram_pkg.all;
    constant datawidth  : natural := 32;
    constant used_radix : natural := 20;

    constant ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 5, datawidth => datawidth);
    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 1, datawidth => 32, addresswidth => 8);
    signal instr_ram_read_in   : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out  : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in  : instr_ref_subtype.ram_write_in'subtype;

    signal pim_ram_write     : ref_subtype.ram_write_in'subtype;
    signal add_sub_ram_write : ref_subtype.ram_write_in'subtype;

    constant test_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(ref_subtype.data'range) := (
          101 => to_fixed(1.5  , datawidth , used_radix)
        , 102 => to_fixed(0.5  , datawidth , used_radix)
        , 103 => to_fixed(-1.5 , datawidth , used_radix)
        , 104 => to_fixed(-0.5 , datawidth , used_radix)
        , 105 => to_fixed(-1.0 , datawidth , used_radix)

        , others => (others => '0'));

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(instr_ref_subtype.data'range) := (
        6   => sub( 96, 101,101)

        , 7  => sub( 100 , 101 , 102)
        , 8  => sub( 99  , 102 , 101)
        , 9  => add( 98  , 103 , 104)
        , 10 => add( 97  , 104 , 103)
        , 11 => op(mpy_add , 96  , 101 , 104  , 105)
        , 12 => op(mpy_add , 95  , 102 , 104  , 102)

        , others => op(program_end));

    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    signal processor_enabled : boolean := true;
    signal processor_requested : boolean := false;

    use work.instruction_pkg.all;
    constant instruction_in_ref : instruction_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (others => op(nop))
        );

    constant instruction_out_ref : instruction_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
        );

    signal addsub_in : instruction_in_ref'subtype := instruction_in_ref;
    signal addsub_out : instruction_out_ref'subtype := instruction_out_ref;

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
------------------------------------------------------------------------
    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
        end if; -- rising_edge
    end process stimulus;	
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    port map(simulator_clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => processor_enabled
    , instr_pipeline      => instr_pipeline
    , processor_requested => processor_requested
    , start_address       => 0);
-- ----------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(radix => used_radix)
    port map(simulator_clock 
    ,addsub_in
    ,addsub_out);

    addsub_in <= (ram_read_out, instr_ram_read_out, instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------

    u_instruction_ram : entity work.multi_port_ram
    generic map(test_program)
    port map(
        clock => simulator_clock
        ,ram_read_in  => instr_ram_read_in
        ,ram_read_out => instr_ram_read_out
        ,ram_write_in => instr_ram_write_in);

    u_dataram : entity work.multi_port_ram
    generic map(test_data)
    port map(
        clock => simulator_clock
        ,ram_read_in  => addsub_out.data_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => addsub_out.ram_write_in);
------------------------------------------------------------------------
end vunit_simulation;
