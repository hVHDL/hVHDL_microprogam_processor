--------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.instruction_pkg.all;

entity float_processor is
    generic(
            g_instruction_bit_width      : natural := 32
            ;g_data_bit_width            : natural := 32
            ;g_number_of_pipeline_stages : natural := 10
            ;g_used_radix                : natural
            ;g_addresswidth              : natural := 10
            ;g_program                   : work.dual_port_ram_pkg.ram_array
            ;g_data                      : work.dual_port_ram_pkg.ram_array
            ;g_idle_ram_write            : ram_write_in_record := init_write_in(g_addresswidth, g_data_bit_width)
           );
    port(
        clock        : in std_logic
        ;mproc_in    : in work.microprogram_processor_pkg.microprogram_processor_in_record
        ;mproc_out   : out work.microprogram_processor_pkg.microprogram_processor_out_record
        ;mc_read_in  : out ram_read_in_array
        ;mc_read_out : in ram_read_out_array
        ;mc_output   : out ram_write_in_record
        ;mc_write_in : in ram_write_in_record := g_idle_ram_write
        ------ instruction entity connection
        ;instruction_in  : out instruction_in_record
        ;instruction_out : in instruction_out_record
    );
end float_processor;

architecture rtl of float_processor is

    constant ref_subtype       : subtype_ref_record := create_ref_subtypes(readports => 3 , datawidth => g_data_bit_width);
    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 1 , datawidth => 32   , addresswidth => 10);

    signal instr_ram_read_in   : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out  : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in  : instr_ref_subtype.ram_write_in'subtype;

    signal ram_read_in : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in      : ref_subtype.ram_write_in'subtype;

    signal data_ram_read_out : ref_subtype.ram_read_out'subtype;

    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    signal write_buffer : mc_write_in'subtype := g_idle_ram_write;

begin

    instruction_in  <= (data_ram_read_out, instr_ram_read_out, instr_pipeline);
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    port map(clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => mproc_out.is_busy
    , instr_pipeline      => instr_pipeline
    , processor_requested => mproc_in.processor_requested
    , start_address       => mproc_in.start_address
    , is_ready            => mproc_out.is_ready);
----------------------------------------------------------
----
    u_program_ram : entity work.multi_port_ram
    generic map(g_program)
    port map(
        clock => clock
        ,ram_read_in  => instr_ram_read_in(0 to 0)
        ,ram_read_out => instr_ram_read_out(0 to 0)
        ,ram_write_in => instr_ram_write_in);
----
    u_data_ram : entity work.multi_port_ram
    generic map(g_data)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);

------------------------------------------------------------------------
------------------------------------------------------------------------
    combine_ram_buses : process(all) is
    begin
        -- if rising_edge(clock)
        -- then
            mc_read_in   <= combine((0 => instruction_out.data_read_in) , ref_subtype.address , no_map_range_low => 0   , no_map_range_hi => 118);
            ram_read_in  <= combine((0 => instruction_out.data_read_in) , ref_subtype.address , no_map_range_low => 119 , no_map_range_hi => 127);

            ram_write_in <= combine((0 => instruction_out.ram_write_in));

            -- add buffering for writing ram externally when not written by processor
            -- if write_requested(ram_write_in) then
            --     write_buffer <= ram_write_in;
            -- end if;

            -- if not write_requested(add_sub_ram_write)
            -- then
            --     if write_requested(ram_write_in) 
            --         or write_requested(write_buffer)
            --     then
            --         ram_write_in <= combine((0 => mc_write_in));
            --     end if;
            -- end if;

            for i in ram_read_out'range loop
                if mc_read_out(i).data_is_ready then
                    data_ram_read_out(i).data          <= mc_read_out(i).data;
                    data_ram_read_out(i).data_is_ready <= mc_read_out(i).data_is_ready;
                else
                    data_ram_read_out(i) <= ram_read_out(i);
                end if;
            end loop;
        -- end if;
    end process combine_ram_buses;

    mc_output <= ram_write_in;

-------------------------------
end rtl;

LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microprogram_processor_pkg.all;
    use work.microinstruction_pkg.all;

entity float_microprocessor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of float_microprocessor_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    constant instruction_length : natural := 40;
    constant word_length : natural := 32;
    constant used_radix : natural := 20;

    --
    use work.real_to_fixed_pkg.all;
    function to_fixed is new generic_to_fixed 
        generic map(word_length => word_length, used_radix => used_radix);
    --

    use work.multi_port_ram_pkg.all;

    constant ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 3, datawidth => word_length, addresswidth => 10);
    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 1, datawidth => 32, addresswidth => 10);

    signal mc_read_in  : ref_subtype.ram_read_in'subtype;
    signal mc_read_out : ref_subtype.ram_read_out'subtype;
    signal mc_output   : ref_subtype.ram_write_in'subtype;
    ----
    use work.ram_connector_pkg.all;

    constant readports : natural := 3;
    constant addresswidth : natural := 10;
    constant datawidth : natural := word_length;

    constant ram_connector_ref : ram_connector_record := create_ref_subtype(readports => readports, addresswidth => addresswidth, datawidth => datawidth);

    signal ram_connector : ram_connector_ref'subtype;

    signal test1 : real := 0.0;
    signal test2 : real := 0.0;
    signal test3 : real := 0.0;
    signal test4 : real := 0.0;
    signal test5 : real := 0.0;

    constant y    : natural := 50;
    constant u    : natural := 60;
    constant uext : natural := 120;
    constant g    : natural := 70;

    constant load             : natural := 121;
    constant duty             : natural := 122;
    constant input_voltage    : natural := 123;

    constant inductor_current : natural := 22;
    constant cap_voltage      : natural := 23;
    constant ind_res          : natural := 24;
    constant current_gain     : natural := 26;
    constant voltage_gain     : natural := 27;
    constant inductor_voltage : natural := 29;
    constant rxi              : natural := 30;
    constant cap_current      : natural := 31;

    constant sampletime : real := 1.0e-6;

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(ref_subtype.data'range) := (
           0 => to_fixed(0.0)
        ,  1 => to_fixed(1.0)
        ,  2 => to_fixed(2.0)
        ,  3 => to_fixed(-3.0)

        , duty             => to_fixed(0.5)
        , inductor_current => to_fixed(0.0)
        , cap_voltage      => to_fixed(0.0)
        , ind_res          => to_fixed(0.9)
        , load             => to_fixed(0.0)
        , current_gain     => to_fixed(sampletime*1.0/2.0e-6)
        , voltage_gain     => to_fixed(sampletime*1.0/3.0e-6)
        , input_voltage    => to_fixed(10.0)
        , inductor_voltage => to_fixed(0.0)

        , others => (others => '0')
    );

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(instr_ref_subtype.data'range) := (
        6    => sub(5, 1, 1)
        , 7  => add(6, 1, 1)
        , 8  => mpy(7, 2, 2)
        , 9  => op(mpy_add,8, 2, 2, 1)
        , 10 => op(mpy_sub,9, 2, 2, 1)
        , 13 => op(program_end)

        -- equation:
        -- didt = input_voltage - duty*dc_link - i*rl
        -- dudt = i*duty - iload

        -- u = u + dudt*h/c
        -- i = i + didt*h/c

        -- lc filter
        , 128 => op(set_rpt     , 200)
        , 129 => op(neg_mpy_add , inductor_voltage , duty             , cap_voltage      , input_voltage)
        , 130 => op(mpy_sub     , cap_current      , duty             , inductor_current , load)
        , 136 => op(neg_mpy_add , inductor_voltage , ind_res          , inductor_current , inductor_voltage)
        , 137 => op(mpy_add     , cap_voltage      , cap_current      , voltage_gain     , cap_voltage)
        , 140 => op(jump        , 129)
        , 143 => op(mpy_add     , inductor_current , inductor_voltage , current_gain     , inductor_current)

        , others => op(nop));

    ----
    signal ext_input : std_logic_vector(word_length-1 downto 0) := to_fixed(-22.351);

    signal current : real := 0.0;
    signal voltage : real := 0.0;

    signal lc_load : std_logic_vector(word_length-1 downto 0)          := to_fixed(0.0);
    signal lc_duty : std_logic_vector(word_length-1 downto 0)          := to_fixed(0.5);
    signal lc_input_voltage : std_logic_vector(word_length-1 downto 0) := to_fixed(10.0);

    signal mproc_in  : microprogram_processor_in_record;
    signal mproc_out : microprogram_processor_out_record;

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
    stimulus : process(simulator_clock)

        function convert(data_in : std_logic_vector) return real is
        begin
            return to_real(signed(data_in), used_radix);
        end convert;

        procedure connect_ram_write_to_address is new generic_connect_ram_write_to_address generic map(return_type => real, conv => convert);


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            init_ram_connector(ram_connector);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 120, ext_input);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 121, lc_load);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 122, lc_duty);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 123, lc_input_voltage);

            init_mproc(mproc_in);
            CASE simulation_counter is
                when 0 =>
                    calculate(mproc_in, 6);

                when 50 => 
                    lc_load <= to_fixed(2.3);
                    lc_duty <= to_fixed(0.9);
                    calculate(mproc_in, 128);

                when 800 => lc_duty <= to_fixed(0.6);
                when 1600 => 
                    -- lc_load <= to_fixed(1.3);
                WHEN others => --do nothing
            end CASE;

            connect_ram_write_to_address(mc_output, 5, test1);
            connect_ram_write_to_address(mc_output, 6, test2);
            connect_ram_write_to_address(mc_output, 7, test3);
            connect_ram_write_to_address(mc_output, 8, test4);
            connect_ram_write_to_address(mc_output, 9, test5);

            connect_ram_write_to_address(mc_output , inductor_current , current);
            connect_ram_write_to_address(mc_output , cap_voltage      , voltage);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_float_processor : entity work.float_processor
    generic map(g_used_radix => used_radix, g_program => test_program, g_data => program_data)
    port map(simulator_clock, mproc_in, mproc_out, mc_read_in, mc_read_out, mc_output, instruction_in => addsub_in, instruction_out => addsub_out);
------------------------------------------------------------------------
    dingdong : entity work.instruction(float_mult_add)
    generic map(radix => 20)
    port map(simulator_clock 
    ,addsub_in
    ,addsub_out);

end vunit_simulation;
