library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package microprogram_processor_pkg is

    type microprogram_processor_in_record is record
        processor_requested  : boolean;
        start_address        : natural;
    end record;

    type microprogram_processor_out_record is record
        is_busy : boolean;
    end record;

    procedure init_mproc (signal self_in : out microprogram_processor_in_record);
    procedure calculate (signal self_in : out microprogram_processor_in_record; start_address : in natural);

end package microprogram_processor_pkg;

------------------

package body microprogram_processor_pkg is

    procedure init_mproc (signal self_in : out microprogram_processor_in_record) is
    begin
        self_in.processor_requested <= false;
    end init_mproc;

    procedure calculate (signal self_in : out microprogram_processor_in_record; start_address : in natural) is
    begin
        self_in.processor_requested <= true;
        self_in.start_address <= start_address;
    end calculate;


end package body microprogram_processor_pkg;

--------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

entity microprogram_processor is
    generic(
            package processor_microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
            ;package processor_mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
            ;g_used_radix : natural
            ;g_program : processor_mp_ram_pkg.ram_array
            ;g_data : processor_mp_ram_pkg.ram_array
           );
    port(
        clock        : in std_logic
        ;mproc_in    : in work.microprogram_processor_pkg.microprogram_processor_in_record
        ;mc_read_in  : out processor_mp_ram_pkg.ram_read_in_array(0 to 3)
        ;mc_read_out : in processor_mp_ram_pkg.ram_read_out_array(0 to 3)
        ;mc_output   : out processor_mp_ram_pkg.ram_write_in_record
    );
end microprogram_processor;

architecture rtl of microprogram_processor is

    alias calculate is mproc_in.processor_requested;
    alias start_address is mproc_in.start_address;

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(
                    g_instruction_bit_width     => processor_microinstruction_pkg.instruction_bit_width
                    ,g_data_bit_width            => processor_microinstruction_pkg.data_bit_width
                    ,g_number_of_pipeline_stages => processor_microinstruction_pkg.number_of_pipeline_stages);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.data_bit_width
        ,g_ram_depth_pow2 => 10);
        use mp_ram_pkg.all;

    signal ram_read_in : ram_read_in_array(0 to 3);
    signal pc_read_in  : ram_read_in_array(0 to 3);
    signal sub_read_in : ram_read_in_array(0 to 3);
    signal ext_read_in : ram_read_in_array(0 to 3);

    signal ram_write_in      : ram_write_in_record;
    signal pim_ram_write     : ram_write_in_record;
    signal add_sub_ram_write : ram_write_in_record;

    signal ram_write_in1      : ram_write_in_record;

    signal ram_read_out : ram_read_out_array(ram_read_in'range);
    signal data_ram_read_out : ram_read_out_array(ram_read_in'range);

    signal program_ram_read_in : ram_read_in_array(0 to 0);
    signal program_ram_read_out : ram_read_in_array(0 to 0);

    constant used_radix : natural := g_used_radix;

    use work.real_to_fixed_pkg.all;

    function pimpom(a : processor_mp_ram_pkg.ram_array) return mp_ram_pkg.ram_array is
        variable retval : mp_ram_pkg.ram_array;
    begin
        for i in a'range loop
            retval(i) := a(i);
        end loop;

        return retval;
    end pimpom;

    constant test_program : mp_ram_pkg.ram_array := pimpom(g_program);

    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    --
    signal processor_enabled : boolean := false;
    --

begin

----------------------------------------------------------
    process(clock) is
    begin
        if rising_edge(clock)
        then
            processor_mp_ram_pkg.init_mp_write(mc_output);
            if write_requested(ram_write_in) then
                processor_mp_ram_pkg.write_data_to_ram(
                    mc_output
                    ,get_address(ram_write_in)
                    ,get_data(ram_write_in) );

            end if;
        end if;
    end process;
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(microinstruction_pkg, mp_ram_pkg)
    port map(clock 
    , pc_read_in 
    , data_ram_read_out 
    , pim_ram_write 
    , processor_enabled
    , instr_pipeline
    , calculate
    , start_address);
----------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(microinstruction_pkg , mp_ram_pkg , radix => used_radix)
    port map(clock 
    , sub_read_in 
    , data_ram_read_out 
    , add_sub_ram_write 
    , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
----
    combine_ram_buses : process(all) is
    begin

        for i in ext_read_in'range loop
            mc_read_in(i).address        <= ext_read_in(i).address;
            mc_read_in(i).read_requested <= ext_read_in(i).read_requested;
        end loop;

        for i in data_ram_read_out'range loop
            if mc_read_out(i).data_is_ready then
                data_ram_read_out(i).data          <= mc_read_out(i).data;
                data_ram_read_out(i).data_is_ready <= mc_read_out(i).data_is_ready;
            else
                data_ram_read_out(i) <= ram_read_out(i);
            end if;
        end loop;
        data_ram_read_out(0) <= ram_read_out(0);

        ext_read_in  <= combine((0 => pc_read_in    , 1 => sub_read_in)         , no_map_range_hi => 119);
        ram_read_in  <= combine((0 => pc_read_in    , 1 => sub_read_in)         , no_map_range_low => 119);
        ram_write_in <= combine((0 => pim_ram_write , 1 => add_sub_ram_write));
    end process combine_ram_buses;
----
    u_program_ram : entity work.multi_port_ram
    generic map(mp_ram_pkg, test_program)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in(0 to 0)
        ,ram_read_out => ram_read_out(0 to 0)
        ,ram_write_in => ram_write_in1);
----
    u_data_ram : entity work.multi_port_ram
    generic map(mp_ram_pkg, g_data)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in(1 to ram_read_in'high)
        ,ram_read_out => ram_read_out(1 to ram_read_in'high)
        ,ram_write_in => ram_write_in);
---------------------------------------
end rtl;
-------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity retry_microprogram_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of retry_microprogram_processor_tb is

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

    use work.multi_port_ram_pkg.all;
    constant datawidth  : natural := 27;
    constant used_radix : natural := 17;

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
    generic map(microinstruction_pkg)
    port map(simulator_clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => processor_enabled
    , instr_pipeline      => instr_pipeline
    , processor_requested => processor_requested
    , start_address       => 0);
-- ----------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(microinstruction_pkg, radix => used_radix)
    port map(simulator_clock 
    , instr_ram_read_out(0) 
    , ram_read_in
    , ram_read_out 
    , ram_write_in 
    , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
    -- ram_read_in  <= pc_read_in   and sub_read_in;
    -- ram_write_in <= pim_ram_write and add_sub_ram_write;

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
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);
------------------------------------------------------------------------
end vunit_simulation;
