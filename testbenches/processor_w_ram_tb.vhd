LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.NUMERIC_STD.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
    
    use work.ram_read_pkg.all;
    use work.testprogram_pkg.all;
    use work.test_programs_pkg.all;

entity processor_w_ram_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of processor_w_ram_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    constant test_program : program_array := get_low_pass_filter & get_sos_filter & get_dummy;

    impure function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array;
    begin
        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;

    signal ram_contents : ram_array         := init_ram(test_program);
    signal ram_read_port : ram_read_port_record := init_ram_read_port;

    type counter_array is array (integer range 0 to 1) of natural;
    signal counter_pipeline : counter_array :=(others => test_program'high);
    alias program_counter  is counter_pipeline(1);
    signal registers        : realarray     := (0.0 , 1.0 , 2.0 , 3.0 , 4.0 , 5.0 , 6.0 , 0.1 , 0.0);

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
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_ram_read_port(ram_read_port);
            if read_is_requested(ram_read_port) then
                ram_read_port.data <= ram_contents(get_ram_address(ram_read_port));
            end if;

            create_processor(program_counter , get_ram_data(ram_read_port) , registers);

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
