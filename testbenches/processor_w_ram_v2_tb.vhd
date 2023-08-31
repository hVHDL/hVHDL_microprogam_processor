LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.testprogram_pkg.all;
    use work.test_programs_pkg.all;
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.real_to_fixed_pkg.all;

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

    signal result : real := 0.0;
------------------------------------------------------------------------
    constant dummy : program_array := get_dummy;
    constant low_pass_filter : program_array := get_low_pass_filter;
    constant test_program : program_array := get_dummy & get_low_pass_filter;

    signal program_counter : natural := test_program'high;
    signal registers : realarray := (0.0, 0.10, 0.2, 0.3, 0.4, 0.5, 0.6, 0.1, 0.0);

    function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array;
    begin
        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;

    signal ram_contents   : ram_array             := init_ram(test_program);
    signal ram_read_port  : ram_read_port_record  := init_ram_read_port;

    signal ram_read_data_port : ram_read_port_record  := init_ram_read_port;
    signal ram_write_port     : ram_write_port_record := init_ram_write_port;

    signal write_address    : natural := 40;
    signal read_address     : natural := 40;
    signal register_address : natural := 0;

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
            program_counter <= dummy'length;
        end request_low_pass_filter;

        procedure save_registers_to_ram is
        begin
            write_address <= 40-registers'length;
            
        end save_registers_to_ram;

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            ------------------------------
            create_ram_read_port(ram_read_port);
            if read_is_requested(ram_read_port) then
                ram_read_port.data <= ram_contents(get_ram_address(ram_read_port));
            end if;
            create_ram_read_port(ram_read_data_port);
            if read_is_requested(ram_read_data_port) then
                ram_read_data_port.data <= ram_contents(get_ram_address(ram_read_data_port));
            end if;
            create_ram_write_port(ram_write_port);
            if write_is_requested(ram_write_port) then
                ram_contents(get_write_address(ram_write_port)) <= ram_write_port.write_buffer;
            end if;
            ------------------------------
            request_data_from_ram(ram_read_port, program_counter);
            create_processor(program_counter , get_ram_data(ram_read_port) , registers);

            if write_address < 40 then
                write_address <= write_address + 1;
                write_data_to_ram(ram_write_port, write_address, to_fixed(registers(write_address-(40-registers'length)), 19));
            end if;

            if read_address > 30 then
                if read_address < 40 then
                    read_address <= read_address + 1;
                    request_data_from_ram(ram_read_data_port, read_address);
                end if;
            end if;

            if ram_read_is_ready(ram_read_data_port) then
                registers(register_address) <= to_real(get_ram_data(ram_read_data_port), 19);
                register_address <= register_address + 1;
            end if;

            if decode(get_ram_data(ram_read_port)) = ready then
                result <= registers(0);
            end if;
        ------------------------------------------------------------------------
            if simulation_counter = 10 then
                request_low_pass_filter;
            end if;

            if decode(get_ram_data(ram_read_port)) = ready then
                save_registers_to_ram;
            end if;

            if write_address = 40-registers'length then
                read_address <= 40-registers'length;
                register_address <= 0;
            end if;

            if read_address = 39 then
                request_low_pass_filter;
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
