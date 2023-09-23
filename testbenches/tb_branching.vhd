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
    use work.multiplier_pkg.radix_multiply;

entity branching_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of branching_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 10000;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    constant dummy           : program_array := get_dummy;
    constant low_pass_filter : program_array := get_pipelined_low_pass_filter;
    constant test_program    : program_array := get_dummy & get_pipelined_low_pass_filter;

    constant ram_with_registers : ram_array := 
        write_register_values_to_ram(init_ram(test_program) , to_fixed((0.99 , 0.99 , 0.99 , 0.99 , 0.99 , 0.99 , 0.99 , 0.99, 0.99) , 19) , 21+8);

    signal ram_contents : ram_array := ram_with_registers;
    signal self : processor_with_ram_record := init_processor(test_program'high);

    signal test_counter : natural := 0;
    signal result : real := 0.0;

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
        constant ramsize : natural := ram_contents'length;
        variable ram_data : std_logic_vector(19 downto 0);
        constant register_memory_start_address : integer := ramsize-self.registers'length;
        constant zero : std_logic_vector(self.registers(0)'range) := (others => '0');

        procedure request_low_pass_filter is
        begin
            self.program_counter <= dummy'length;
        end request_low_pass_filter;
    ------------------------------------------------------------------------

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            create_ram_read_port(self.ram_read_instruction_port);
            create_ram_read_port(self.ram_read_data_port);
            create_ram_write_port(self.ram_write_port);
            create_ram_write_port(self.ram_write_port2);
            --------------------
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
            --------------------
            if write_is_requested(self.ram_write_port2) then
                ram_contents(get_write_address(self.ram_write_port2)) <= self.ram_write_port2.write_buffer;
            end if;
            --------------------

        --------------------------------------------------
            create_processor_w_ram(self, ram_contents'length);
            test_counter <= test_counter + 1;

            CASE test_counter is
                WHEN 0 => load_registers(self, 21+8);
                WHEN 15 => request_low_pass_filter;
                WHEN 48 => save_registers(self, 21+8);
                WHEN 60 => load_registers(self, 15);
                WHEN 75 => test_counter <= 0;
                WHEN others => --do nothing
            end CASE;

            if decode(self.instruction_pipeline(1)) = ready then
                result <= to_real(signed(self.registers(0)),self.registers(0)'length-1);
            end if;
        --------------------------------------------------
        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
