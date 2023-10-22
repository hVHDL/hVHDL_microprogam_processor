LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.real_to_fixed_pkg.all;
    use work.microcode_processor_pkg.all;
    use work.multi_port_ram_pkg.all;

entity processor_w_ram_v2_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of processor_w_ram_v2_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------
    constant dummy           : program_array := get_dummy;
    constant low_pass_filter : program_array := get_low_pass_filter;
    constant test_program    : program_array := get_dummy & get_low_pass_filter & get_dummy;

    signal self                      : processor_with_ram_record := init_processor(test_program'high);
    signal ram_read_instruction_in  : ram_read_in_record    ;
    signal ram_read_instruction_out : ram_read_out_record    ;
    signal ram_read_data_in         : ram_read_in_record    ;
    signal ram_read_data_out        : ram_read_out_record    ;
    signal ram_write_port           : ram_write_in_record   ;
    signal ram_write_port2          : ram_write_in_record   ;

    signal ram_contents : ram_array := init_ram(test_program);
    signal result       : real := 0.0;

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

        procedure request_low_pass_filter is
        begin
            self.program_counter <= dummy'length;
        end request_low_pass_filter;
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            --------------------

            create_processor_w_ram(
                self                     ,
                ram_read_instruction_in  ,
                ram_read_instruction_out ,
                ram_read_data_in         ,
                ram_read_data_out        ,
                ram_write_port           ,
                ram_array'length);

            if simulation_counter mod 20 = 0 then
                request_low_pass_filter;
            end if;

            if decode(get_ram_data(ram_read_instruction_out)) = ready then
                result <= to_real(signed(self.registers(0)),self.registers(0)'length-1);
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_dpram : entity work.ram_read_x2_write_x1
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
