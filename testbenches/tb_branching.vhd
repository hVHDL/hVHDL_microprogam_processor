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
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    constant dummy           : program_array := get_dummy;
    constant low_pass_filter : program_array := get_pipelined_low_pass_filter;
    constant test_program    : program_array := get_dummy & get_pipelined_low_pass_filter;

    function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;

    signal ram_contents : ram_array := init_ram(test_program);
    signal self : processor_with_ram_record := init_processor(test_program'high);

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

            if self.read_address > register_memory_start_address then
                if self.read_address < ramsize then
                    self.read_address <= self.read_address + 1;
                    request_data_from_ram(self.ram_read_data_port, self.read_address);
                end if;
            end if;

            if ram_read_is_ready(self.ram_read_data_port) then
                self.registers <= self.registers(0 to self.registers'length-2) & get_ram_data(self.ram_read_data_port);
                self.register_address <= self.register_address + 1;
            end if;

            if self.write_address =  register_memory_start_address then
                self.read_address <= register_memory_start_address;
                self.register_address <= 0;
            end if;

        --------------------------------------------------
            -- save registers to ram
            if decode(self.instruction_pipeline(2)) = ready then
                self.write_address <= register_memory_start_address;
            end if;

            if self.write_address < ramsize then
                self.write_address <= self.write_address + 1;
                write_data_to_ram(self.ram_write_port, self.write_address, self.registers(0));
                self.registers <= self.registers(0 to self.registers'length-2) & zero;
            end if;


        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
