LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.NUMERIC_STD.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
    
    use work.ram_read_pkg.all;
    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.microcode_processor_pkg.all;

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

    function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
    begin
        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;

    signal ram_contents : ram_array         := init_ram(test_program);
    signal ram_read_port : ram_read_port_record := init_ram_read_port;

    signal counter_pipeline : counter_array :=(others => test_program'high);
    constant init_registers : reg_array := (others => (others => '0'));
    signal registers        : reg_array     := to_fixed((0.0 , 1.0 , 2.0 , 3.0 , 4.0 , 5.0 , 6.0 , 0.1 , 0.0),init_registers(0)'length);
    signal instruction_pipeline : instruction_array;

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
        procedure low_pass_filter is
            constant dummy : program_array := get_dummy;
        begin
            counter_pipeline(0) <= dummy'length;
            
        end low_pass_filter;
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            create_ram_read_port(ram_read_port);
            if read_is_requested(ram_read_port) then
                ram_read_port.data <= ram_contents(get_ram_address(ram_read_port));
            end if;

            create_processor(counter_pipeline , get_ram_data(ram_read_port), instruction_pipeline , registers);
            request_data_from_ram(ram_read_port, counter_pipeline(0) mod ram_array'length);

            if simulation_counter = 10 or decode(instruction_pipeline(0)) = ready then
                low_pass_filter;
            end if;



        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
