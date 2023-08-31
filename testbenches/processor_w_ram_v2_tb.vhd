LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.testprogram_pkg.all;
    use work.test_programs_pkg.all;
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.real_to_fixed_pkg.all;

package microcode_processor_pkg is


    type processor_with_ram_record is record
        ram_read_port      : ram_read_port_record  ;
        ram_read_data_port : ram_read_port_record  ;
        ram_write_port     : ram_write_port_record ;
        write_address      : natural               ;
        read_address       : natural               ;
        register_address   : natural               ;
        program_counter    : natural;
        registers : realarray;
    end record;

    function init_processor ( program_start_point : natural) return processor_with_ram_record;

    procedure create_processor_w_ram (
        signal self : inout processor_with_ram_record);

end package microcode_processor_pkg;

package body microcode_processor_pkg is

    function init_processor ( program_start_point : natural)
    return processor_with_ram_record
    is
        variable retval : processor_with_ram_record;
    begin
        retval := (
        init_ram_read_port  ,
        init_ram_read_port  ,
        init_ram_write_port ,
        40                  ,
        40                  ,
        0                   ,
        program_start_point,
        (0.0, 0.10, 0.2, 0.3, 0.4, 0.5, 0.6, 0.1, 0.0));
        
        return retval;
    end init_processor;

        procedure create_processor_w_ram
        (
            signal self : inout processor_with_ram_record
        ) is
        begin
            create_ram_read_port(self.ram_read_port);
            create_ram_read_port(self.ram_read_data_port);
            create_ram_write_port(self.ram_write_port);
            request_data_from_ram(self.ram_read_port, self.program_counter);
            create_processor(self.program_counter , get_ram_data(self.ram_read_port) , self.registers);
        --------------------------------------------------
            if self.write_address < 40 then
                self.write_address <= self.write_address + 1;
                write_data_to_ram(self.ram_write_port, self.write_address, to_fixed(self.registers(self.write_address-(40-self.registers'length)), 19));
            end if;

            if self.read_address > 30 then
                if self.read_address < 40 then
                    self.read_address <= self.read_address + 1;
                    request_data_from_ram(self.ram_read_data_port, self.read_address);
                end if;
            end if;

            if ram_read_is_ready(self.ram_read_data_port) then
                self.registers(self.register_address) <= to_real(get_ram_data(self.ram_read_data_port), 19);
                self.register_address <= self.register_address + 1;
            end if;

        ------------------------------------------------------------------------
            
        end create_processor_w_ram;

end package body microcode_processor_pkg;

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

    signal result : real := 0.0;
------------------------------------------------------------------------
    constant dummy : program_array := get_dummy;
    constant low_pass_filter : program_array := get_low_pass_filter;
    constant test_program : program_array := get_dummy & get_low_pass_filter;


    function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array;
    begin
        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;




    signal ram_contents       :  ram_array             := init_ram(test_program);
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

        procedure request_low_pass_filter is
        begin
            self.program_counter <= dummy'length;
        end request_low_pass_filter;

        procedure save_registers_to_ram is
        begin
            self.write_address <= 40-self.registers'length;
            
        end save_registers_to_ram;

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            ------------------------------
            create_processor_w_ram(self);
            if read_is_requested(self.ram_read_port) then
                self.ram_read_port.data <= ram_contents(get_ram_address(self.ram_read_port));
            end if;
            if read_is_requested(self.ram_read_data_port) then
                self.ram_read_data_port.data <= ram_contents(get_ram_address(self.ram_read_data_port));
            end if;
            if write_is_requested(self.ram_write_port) then
                ram_contents(get_write_address(self.ram_write_port)) <= self.ram_write_port.write_buffer;
            end if;
            ------------------------------

            if simulation_counter = 10 then
                request_low_pass_filter;
            end if;

            if decode(get_ram_data(self.ram_read_port)) = ready then
                save_registers_to_ram;
            end if;

            if self.write_address = 40-self.registers'length then
                self.read_address <= 40-self.registers'length;
                self.register_address <= 0;
            end if;

            if self.read_address = 39 then
                request_low_pass_filter;
            end if;

            if decode(get_ram_data(self.ram_read_port)) = ready then
                result <= self.registers(0);
            end if;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
