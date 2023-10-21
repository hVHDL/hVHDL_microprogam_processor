LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.NUMERIC_STD.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
    
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;

entity ram_read_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of ram_read_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    function init_ram return ram_array
    is
        variable retval : ram_array;
    begin
        for i in integer range ram_array'range loop
            retval(i) := std_logic_vector(to_unsigned(i,retval(0)'length));
        end loop;

        return retval;
        
    end init_ram;

    signal ram_contents : ram_array := init_ram;
    signal read_port : ram_read_port_record := init_ram_read_port;
    signal testi : t_ram_data;

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
            create_ram_read_port(read_port);
            if read_is_requested(read_port) then
                read_port.data <= ram_contents(get_ram_address(read_port));
            end if;

            CASE simulation_counter is
                WHEN 10 => request_data_from_ram(read_port, simulation_counter);
                WHEN 11 => request_data_from_ram(read_port, simulation_counter);
                WHEN 12 => request_data_from_ram(read_port, simulation_counter);
                WHEN 13 => request_data_from_ram(read_port, simulation_counter);
                WHEN 15 => request_data_from_ram(read_port, simulation_counter);
                WHEN 16 => request_data_from_ram(read_port, simulation_counter);
                WHEN 18 => request_data_from_ram(read_port, simulation_counter);
                WHEN others => --do nothing
            end CASE;

            if ram_read_is_ready(read_port) then
                check(get_ram_data(read_port) = std_logic_vector(to_unsigned(simulation_counter, ram_bit_width)-2));
                testi <= std_logic_vector(to_unsigned(simulation_counter, 20) - 3);
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
