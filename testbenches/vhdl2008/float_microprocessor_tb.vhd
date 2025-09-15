
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
    constant simtime_in_clocks : integer := 8500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    constant instruction_length : natural := 32;
    constant word_length        : natural := 40;
    constant used_radix         : natural := 20;

    --
    use work.multi_port_ram_pkg.all;

    constant ref_subtype       : subtype_ref_record := 
        create_ref_subtypes(readports => 3 
        , datawidth => word_length        
        , addresswidth => 10);

    constant instr_ref_subtype : subtype_ref_record := 
    create_ref_subtypes(readports => 1 
    , datawidth => instruction_length 
    , addresswidth => 10);

    signal mc_output   : ref_subtype.ram_write_in'subtype;
    signal mc_write_in : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    signal mproc_in     : microprogram_processor_in_record;
    signal mproc_out    : microprogram_processor_out_record;

    use work.instruction_pkg.all;

    constant instruction_in_ref : instruction_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to 20 => op(nop))
        );

    constant instruction_out_ref : instruction_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
        );

    signal addsub_in  : instruction_in_ref'subtype  := instruction_in_ref;
    signal addsub_out : instruction_out_ref'subtype := instruction_out_ref;

    ----

    use work.float_to_real_conversions_pkg.all;
    use work.float_typedefs_generic_pkg.all;

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
    constant cap_current      : natural := 31;

    constant sampletime : real := 0.7e-6;

    constant hfloat_ref : hfloat_record :=(
        sign => '0'
        ,exponent => (7 downto 0 => x"00")
        ,mantissa => (word_length-2-8 downto 0 => (word_length-2-8 downto 0 => '0')));

    function to_hfloat is new to_hfloat_slv_generic generic map(8,word_length);

    constant program_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(ref_subtype.data'range) := (
           0 => to_hfloat(0.0)
        ,  1 => to_hfloat(1.0)
        ,  2 => to_hfloat(2.0)
        ,  3 => to_hfloat(-3.0)

        , duty             => to_hfloat(0.9)
        , inductor_current => to_hfloat(0.0)
        , cap_voltage      => to_hfloat(12.0)
        , ind_res          => to_hfloat(0.4)
        , load             => to_hfloat(0.0)
        , current_gain     => to_hfloat(sampletime*1.0/3.0e-6)
        , voltage_gain     => to_hfloat(sampletime*1.0/3.0e-6)
        , input_voltage    => to_hfloat(10.0)
        , inductor_voltage => to_hfloat(0.0)

        , 51   => to_hfloat(-2.0)
        , 52   => to_hfloat(0.1235)
        , 53   => to_hfloat(2.0)
        , 54   => to_hfloat(10.0e6)
        , 55   => to_hfloat(1.0)

        , others => (others => '0')
    );

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(instr_ref_subtype.data'range) := (
        0 => op(nop)

        , 14 => op(mpy_add      , 5 , 51 , 51 , 51)
        , 15 => op(mpy_sub      , 6 , 51 , 51 , 51)
        , 16 => op(neg_mpy_add  , 7 , 51 , 51 , 51)
        , 17 => op(neg_mpy_sub  , 8 , 51 , 51 , 51)
        , 18 => op(mpy_add      , 9 , 55      , 53      , 54)
        , 23 => op(program_end)

        -- equation:
        -- didt = input_voltage - duty*dc_link - i*rl
        -- dudt = i*duty - iload

        -- u = u + dudt*h/c
        -- i = i + didt*h/c

        -- lc filter
        , 128 => op(set_rpt     , 1500)
        , 129 => op(neg_mpy_add , inductor_voltage , duty             , cap_voltage      , input_voltage)
        , 130 => op(mpy_sub     , cap_current      , duty             , inductor_current , load)
        , 142 => op(neg_mpy_add , inductor_voltage , ind_res          , inductor_current , inductor_voltage)
        , 143 => op(mpy_add     , cap_voltage      , cap_current      , voltage_gain     , cap_voltage)
        , 153 => op(jump        , 129)
        , 156 => op(mpy_add     , inductor_current , inductor_voltage , current_gain     , inductor_current)

        , others => op(nop));

    --- test signals
    signal current : real := 0.0;
    signal voltage : real := 0.0;
    signal test1 : real := 0.0;
    signal test2 : real := 1.0;
    signal test3 : real := 0.0;
    signal test4 : real := 0.0;
    signal test5 : real := 0.0;
    ----

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
            return to_real(to_hfloat(data_in, hfloat_ref));
        end convert;

        use work.ram_connector_pkg.generic_connect_ram_write_to_address;
        procedure connect_ram_write_to_address is new generic_connect_ram_write_to_address generic map(return_type => real, conv => convert);


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            init_mproc(mproc_in);
            init_mp_write(mc_write_in);

            CASE simulation_counter is
                when 0  => calculate(mproc_in, 14);
                when 30 => calculate(mproc_in, 14);

                when 34 => write_data_to_ram(mc_write_in, 53, to_hfloat(3.51));
                when 35 => write_data_to_ram(mc_write_in, 53, to_hfloat(4.51));
                when 36 => write_data_to_ram(mc_write_in, 53, to_hfloat(5.51));
                when 37 => write_data_to_ram(mc_write_in, 53, to_hfloat(6.51));
                when 38 => write_data_to_ram(mc_write_in, 53, to_hfloat(7.51));
                when 39 => write_data_to_ram(mc_write_in, 53, to_hfloat(8.51));
                when 40 => write_data_to_ram(mc_write_in, 53, to_hfloat(9.51));

                when 60  => calculate(mproc_in, 14);
                when 90  => calculate(mproc_in, 14);
                when 150 => calculate(mproc_in, 128);

                when 2000 => write_data_to_ram(mc_write_in, duty, to_hfloat(0.81));
                when 3800 => write_data_to_ram(mc_write_in, load, to_hfloat(7.81));
                when 3801 => write_data_to_ram(mc_write_in, duty, to_hfloat(0.75));

                WHEN others => --do nothing
            end CASE;

            connect_ram_write_to_address(mc_output , 5                , test1);
            connect_ram_write_to_address(mc_output , 6                , test2);
            connect_ram_write_to_address(mc_output , 7                , test3);
            connect_ram_write_to_address(mc_output , 8                , test4);
            connect_ram_write_to_address(mc_output , 9                , test5);
            connect_ram_write_to_address(mc_output , inductor_current , current);
            connect_ram_write_to_address(mc_output , cap_voltage      , voltage);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_microprogram_processor : entity work.microprogram_controller
    generic map(g_program => test_program, g_data => program_data, g_data_bit_width => word_length)
    port map(simulator_clock
    ,mproc_in
    ,mproc_out
    ,mc_output
    ,mc_write_in
    ,instruction_in  => addsub_in
    ,instruction_out => addsub_out);
------------------------------------------------------------------------
    u_float_mult_add : entity work.instruction(float_mult_add)
    generic map(radix => 20)
    port map(simulator_clock 
    ,addsub_in
    ,addsub_out);
------------------------------------------------------------------------

end vunit_simulation;
