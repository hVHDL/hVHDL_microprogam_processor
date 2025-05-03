LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity mproc_test_modeling_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of mproc_test_modeling_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    constant instruction_length : natural := 40;
    constant word_length : natural := 40;
    constant used_radix : natural := 30;

    --
    use work.real_to_fixed_pkg.all;
    function to_fixed is new generic_to_fixed 
        generic map(word_length => word_length, used_radix => used_radix);
    --
    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(
           g_instruction_bit_width => instruction_length
           ,g_data_bit_width   => word_length
           ,g_number_of_pipeline_stages => 6);
        use microinstruction_pkg.all;
    --
    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.data_bit_width
        ,g_ram_depth_pow2 => 10);
        use mp_ram_pkg.all;
    --

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

    constant program_data : ram_array :=(
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

    constant test_program : ram_array :=(
        6    => sub(5, 1, 1)
        , 7  => add(6, 1, 1)
        , 8  => mpy(7, 2, 2)
        , 9  => op(mpy_add,8, 2, 2, 1)
        , 10  => op(mpy_sub,9, 2, 2, 1)
        , 13 => op(program_end)

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
    signal mc_read_in  : ram_read_in_array(0 to 3);
    signal mc_read_out : ram_read_out_array(0 to 3);
    signal mc_output   : ram_write_in_record;
    ----
    package ram_connector_pkg is new work.generic_ram_connector_pkg generic map(mp_ram_pkg);
        use ram_connector_pkg.all;

    signal ram_connector : ram_connector_record(read_in(0 to 3), read_out(0 to 3));

    signal ext_input : std_logic_vector(word_length-1 downto 0) := to_fixed(-22.351);

    procedure generic_connect_ram_write_to_address
    generic( type return_type
            ;function conv(a : std_logic_vector) return return_type is <>)
    (
        write_in : in ram_write_in_record
        ; address : in natural
        ; signal data : out return_type
    ) is
    begin
        if write_requested(write_in,address) then
            data <= conv(get_data(write_in));
        end if;
    end generic_connect_ram_write_to_address;

    signal current : real := 0.0;
    signal voltage : real := 0.0;

    signal lc_load : std_logic_vector(word_length-1 downto 0)          := to_fixed(0.0);
    signal lc_duty : std_logic_vector(word_length-1 downto 0)          := to_fixed(0.5);
    signal lc_input_voltage : std_logic_vector(word_length-1 downto 0) := to_fixed(10.0);

    use work.microprogram_processor_pkg.all;
    signal mproc_in : microprogram_processor_in_record;

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
    u_microprogram_processor : entity work.microprogram_processor
    generic map(microinstruction_pkg, mp_ram_pkg, used_radix, test_program, program_data)
    port map(simulator_clock, mproc_in.processor_requested, mproc_in.start_address, mc_read_in, mc_read_out, mc_output);
------------------------------------------------------------------------
end vunit_simulation;
