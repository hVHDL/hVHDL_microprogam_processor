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
    constant simtime_in_clocks : integer := 2200;
    
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
        g_ram_bit_width   => microinstruction_pkg.data_bit_width
        ,g_ram_depth_pow2 => 10);
        use mp_ram_pkg.all;

    signal test1 : real := 0.0;
    signal test2 : real := 0.0;
    signal test3 : real := 0.0;
    signal test4 : real := 0.0;
    signal test5 : real := 0.0;

    constant used_radix : natural := 20;

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

    constant program_data : ram_array :=(
           0 => to_fixed(0.0   , 32 , used_radix)
        ,  1 => to_fixed(1.0   , 32 , used_radix)
        ,  2 => to_fixed(2.0   , 32 , used_radix)
        ,  3 => to_fixed(-3.0   , 32 , used_radix)
        , 11 => to_fixed(1.5   , 32 , used_radix)

        , 12  => to_fixed(0.5        , 32 , used_radix)
        , 13  => to_fixed(-2.5       , 32 , used_radix)
        , 14  => to_fixed(-0.65      , 32 , used_radix)
        , 15  => to_fixed(-1.0       , 32 , used_radix)


        , duty             => to_fixed(0.5               , 32 , used_radix)
        , inductor_current => to_fixed(0.0               , 32 , used_radix)
        , cap_voltage      => to_fixed(0.0               , 32 , used_radix)
        , ind_res          => to_fixed(0.9               , 32 , used_radix)
        , load             => to_fixed(0.0               , 32 , used_radix)
        , current_gain     => to_fixed(1.0/2.0e-6*1.0e-6 , 32 , used_radix)
        , voltage_gain     => to_fixed(1.0/3.0e-6*1.0e-6 , 32 , used_radix)
        , input_voltage    => to_fixed(10.0              , 32 , used_radix)
        , inductor_voltage => to_fixed(0.0               , 32 , used_radix)


        , g   => to_fixed(1.0/10.6359 , 32 , used_radix)
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
        6   => sub( 6, 11,11)
        , 7  => sub( 10 , 11 , 12)
        , 8  => sub( 9  , 12 , 11)
        , 9  => add( 8  , 13 , 14)
        , 10 => add( 7  , 14 , 13)
        , 11 => op(mpy_add , 6  , 11 , 14  , 15)
        , 13 => op(program_end)

        , 16 => sub(6  , 11 , 11)
        , 17 => sub(10 , 11 , 12)
        , 18 => sub(9  , 12 , 11)
        , 19 => add(8  , 13 , 14)
        , 20 => add(7  , 14 , 13)
        , 21 => op(mpy_add      , 6  , 11 , 14  , 15)
        , 23 => op(program_end)

        , 118 => op(set_rpt, 80)

        , 119 => op(lp_filter , y    , u   , y   , g)
        , 120 => op(lp_filter , y+1  , u+1 , y+1 , g+1)

        , 121 => op(jump          , 119)
        , 122 => op(lp_filter , y+2 , uext , y+2 , g+2)
        , 123 => op(lp_filter , y+3 , u+3  , y+3 , g+3)
        , 124 => op(lp_filter , y+4 , u+4  , y+4 , g+4)

        , 125 => op(neg_mpy_sub , y+4 , 1  , 2, 1)
        , 126 => op(lp_filter , y+4 , u+4  , y+4 , g+4)
        , 127 => op(program_end)

        -- lc filter
        , 128 => op(set_rpt     , 200)
        , 129 => op(neg_mpy_add , inductor_voltage , duty             , cap_voltage      , input_voltage)
        , 130 => op(mpy_sub     , cap_current      , duty             , inductor_current , load)
        , 136 => op(neg_mpy_add , inductor_voltage , ind_res          , inductor_current , inductor_voltage)
        , 137 => op(mpy_add     , cap_voltage      , cap_current      , voltage_gain     , cap_voltage)
        , 140 => op(jump        , 129)
        , 143 => op(mpy_add     , inductor_current , inductor_voltage , current_gain     , inductor_current)

        , others => op(nop));

    --------------------
    function generic_op 
        generic (
            type t_lista
            ;function get_pos(a : t_lista) return natural is <>
        )
        parameter (x : t_lista) return natural is
    begin
        return get_pos(x);
    end generic_op;
    --------------------

    type test_list is (eka, toka, kolmas, neljas);

    --------------------
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
    package ram_connector_pkg is new work.generic_ram_connector_pkg generic map(mp_ram_pkg);
        use ram_connector_pkg.all;

    signal ram_connector : ram_connector_record(read_in(0 to 3), read_out(0 to 3));

    signal ext_input : std_logic_vector(31 downto 0) := to_fixed(-22.351, 32, used_radix);


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


    use work.microprogram_processor_pkg.all;

    signal mproc_in : microprogram_processor_in_record;

    signal current : real := 0.0;
    signal voltage : real := 0.0;

    signal lc_load : std_logic_vector(31 downto 0) := to_fixed(0.0, 32, used_radix);
    signal lc_duty : std_logic_vector(31 downto 0) := to_fixed(0.5, 32, used_radix);
    signal lc_input_voltage : std_logic_vector(31 downto 0) := to_fixed(10.0, 32, used_radix);

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

        function to_fixed is new generic_to_fixed generic map (32, used_radix);

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;


            init_mproc(mproc_in);
            CASE simulation_counter is
                WHEN 5 =>
                    calculate(mproc_in, 22);
                WHEN 25 =>
                    calculate(mproc_in, 8);

                WHEN 50 =>
                    calculate(mproc_in, 118);
                WHEN 600 =>
                    calculate(mproc_in, 128);
                WHEN others => -- do nothing
            end CASE;

            init_ram_connector(ram_connector);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 120, ext_input);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 121, lc_load);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 122, lc_duty);
            connect_data_to_ram_bus(ram_connector, mc_read_in, mc_read_out, 123, lc_input_voltage);

            CASE simulation_counter is
                when 0 => lc_duty <= to_fixed(0.9);
                    lc_load <= to_fixed(2.3);
                when 1400 => lc_duty <= to_fixed(0.6);
                when 1600 => 
                    -- lc_load <= to_fixed(1.3);
                WHEN others => --do nothing
            end CASE;

            connect_ram_write_to_address(mc_output, 50, test1);
            connect_ram_write_to_address(mc_output, 51, test2);
            connect_ram_write_to_address(mc_output, 52, test3);
            connect_ram_write_to_address(mc_output, 53, test4);
            connect_ram_write_to_address(mc_output, 54, test5);

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
