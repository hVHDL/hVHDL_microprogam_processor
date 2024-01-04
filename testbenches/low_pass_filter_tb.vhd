LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.simple_processor_pkg.all;
    use work.test_programs_pkg.build_sw;

entity low_pass_filter_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of low_pass_filter_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------
    constant ram_contents : ram_array := build_sw;

    signal self                     : simple_processor_record := init_processor;
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

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
    ------------------------------------------------------------------------
    ------------------------------------------------------------------------

        procedure request_program is
        begin
            self.program_counter <= 0;
            self.processor_enabled <= true;
        end request_program;


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            create_simple_processor (
                self                    ,
                ram_read_instruction_in ,
                ram_read_instruction_out,
                ram_read_data_in        ,
                ram_read_data_out       ,
                ram_write_port);
        ------------------------------------------------------------------------
            if simulation_counter mod 55 = 0 then
                request_program;
            end if;
        ------------------------------------------------------------------------
        -- test signals
        ------------------------------------------------------------------------

        end if; -- rising_edge
    end process stimulus;	

------------------------------------------------------------------------
    u_mpram : entity work.ram_read_x2_write_x1
    generic map(ram_contents)
    port map(
    simulator_clock          ,
    ram_read_instruction_in  ,
    ram_read_instruction_out ,
    ram_read_data_in         ,
    ram_read_data_out        ,
    ram_write_port);
------------------------------------------------------------------------
end vunit_simulation;
