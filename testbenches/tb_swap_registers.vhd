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

entity tb_swap_registers is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_swap_registers is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 100;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    function init_ram return ram_array
    is
        variable retval : ram_array;
    begin

        for i in ram_array'range loop
            retval(i) := std_logic_vector(to_signed(i,retval(0)'length));
        end loop;

        return retval;
    end init_ram;

    constant dummy           : program_array := get_dummy;
    constant low_pass_filter : program_array := get_pipelined_low_pass_filter;
    constant test_program    : program_array := get_dummy & get_pipelined_low_pass_filter;

    constant ram_with_registers : ram_array := write_register_values_to_ram(init_ram, (others => (others => '1')), 35);

    signal ram_contents : ram_array := ram_with_registers;
    signal self                      : processor_with_ram_record := init_processor(test_program'high);
    signal ram_read_instruction_port : ram_read_port_record    := init_ram_read_port ;
    signal ram_read_data_port        : ram_read_port_record    := init_ram_read_port ;
    signal ram_write_port            : ram_write_port_record   := init_ram_write_port;
    signal ram_write_port2           : ram_write_port_record   := init_ram_write_port;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        -- if run("registers were same after swapping") then
            check(ram_contents = ram_with_registers);
        -- end if;
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

        constant offset1 : integer := 63;
    ------------------------------------------------------------------------

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            create_ram_read_port(ram_read_instruction_port);
            create_ram_read_port(ram_read_data_port);
            create_ram_write_port(ram_write_port);
            create_ram_write_port(ram_write_port2);
            --------------------
            if read_is_requested(ram_read_instruction_port) then
                ram_read_instruction_port.data <= ram_contents(get_ram_address(ram_read_instruction_port));
            end if;
            --------------------
            if read_is_requested(ram_read_data_port) then
                ram_read_data_port.data <= ram_contents(get_ram_address(ram_read_data_port));
            end if;
            --------------------
            if write_is_requested(ram_write_port) then
                ram_contents(get_write_address(ram_write_port)) <= ram_write_port.write_buffer;
            end if;
            --------------------
            if write_is_requested(ram_write_port2) then
                ram_contents(get_write_address(ram_write_port2)) <= ram_write_port2.write_buffer;
            end if;
            --------------------

            create_processor_w_ram(
                self                      ,
                ram_read_instruction_port ,
                ram_read_data_port        ,
                ram_write_port            ,
                ram_write_port2           ,
                ram_array'length);
            self.program_counter <= 0;

        --------------------------------------------------
            CASE simulation_counter is
                WHEN 10 => load_registers(self, 35);
                WHEN 23 => save_registers(self, 63);
                           load_registers(self, 63);
                WHEN 45 => save_old_and_load_new_registers(self, 63, 63);
                WHEN 60 => load_registers(self, 15);
                WHEN 75 => save_old_and_load_new_registers(self, 15, 15);
                WHEN others => --do nothing
            end CASE;
        --------------------------------------------------
        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
