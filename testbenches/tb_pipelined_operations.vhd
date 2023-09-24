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

entity tb_pipelined_operations is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_pipelined_operations is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 30e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------
    constant dummy           : program_array := get_dummy;
    constant low_pass_filter : program_array := get_pipelined_low_pass_filter;
    constant test_program    : program_array := get_dummy & get_pipelined_low_pass_filter;

    signal ram_contents : ram_array := 
        write_register_values_to_ram(
        write_register_values_to_ram(
        write_register_values_to_ram(
            init_ram(test_program), 
            to_fixed((0.0 , 0.44252 , 0.1   , 0.1   , 0.1   , 0.1   , 0.1   , 0.0104166 , 0.1)   , 19) , 53-reg_array'length*0)  ,
            to_fixed((0.0 , 0.44252 , 0.2   , 0.2   , 0.2   , 0.2   , 0.2   , 0.0804166 , 0.2)   , 19) , 53-reg_array'length*1)  ,
            to_fixed((0.0 , 0.44252 , -0.99 , -0.99 , -0.99 , -0.99 , -0.99 , 0.1804166 , -0.99) , 19) , 53-reg_array'length*2);

    signal self                      : processor_with_ram_record := init_processor(test_program'high);
    signal ram_read_instruction_port : ram_read_port_record    := init_ram_read_port ;
    signal ram_read_data_port        : ram_read_port_record    := init_ram_read_port ;
    signal ram_write_port            : ram_write_port_record   := init_ram_write_port;
    signal ram_write_port2           : ram_write_port_record   := init_ram_write_port;

    signal result       : real := 0.0;
    signal result2      : real := 0.0;
    signal result3      : real := 0.0;
    signal test_counter : natural := 0;

    signal state_counter : natural := 0;

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
------------------------------------------------------------------------
        procedure request_low_pass_filter is
        begin
            self.program_counter <= dummy'length;
        end request_low_pass_filter;

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
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

------------------------------------------------------------------------
            CASE state_counter is
                WHEN 0 => 
                    state_counter <= state_counter+1;
                    load_registers(self, 53-reg_array'length*2);
                WHEN 1 => 
                    if register_load_ready(self) then
                        request_low_pass_filter;
                        state_counter <= state_counter+1;
                    end if;
                WHEN 2 =>
                    if decode(self.instruction_pipeline(1)) = ready then
                        result <= to_real(signed(self.registers(0)),self.registers(0)'length-1);
                        save_registers(self, 53-reg_array'length*2);
                        state_counter <= state_counter+1;
                    end if;
                WHEN 3 =>
                    if register_write_ready(self) then
                        load_registers(self, 15);
                        state_counter <= state_counter+1;
                    end if;
                WHEN 4 =>
                    if register_load_ready(self) then
                        state_counter <= 0;
                    end if;
                WHEN others => -- do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
