LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.real_to_fixed_pkg.all;
    use work.microcode_processor_pkg.all;

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
    function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array;
    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;
    ------------------------
    constant dummy           : program_array := get_dummy;
    constant low_pass_filter : program_array := get_low_pass_filter;
    constant test_program    : program_array := get_dummy & get_low_pass_filter;

    signal ram_contents : ram_array := init_ram(test_program);
    signal self         : processor_with_ram_record := init_processor(test_program'high);
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
            create_processor_w_ram(self, ram_contents'length);
            if read_is_requested(self.ram_read_instruction_port) then
                self.ram_read_instruction_port.data <= ram_contents(get_ram_address(self.ram_read_instruction_port));
            end if;
            --------------------
            if read_is_requested(self.ram_read_data_port) then
                self.ram_read_data_port.data <= ram_contents(get_ram_address(self.ram_read_data_port));
            end if;
            --------------------
            if write_is_requested(self.ram_write_port) then
                ram_contents(get_write_address(self.ram_write_port)) <= self.ram_write_port.write_buffer;
            end if;
------------------------------------------------------------------------
            if simulation_counter mod 20 = 0 then
                request_low_pass_filter;
            end if;

            if decode(get_ram_data(self.ram_read_instruction_port)) = ready then
                result <= self.registers(0);
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
