LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.real_to_fixed_pkg.all;
    use work.microcode_processor_pkg.all;
    use work.multiplier_pkg.radix_multiply;
    use work.multi_port_ram_pkg.all;
    use work.ram_read_control_module_pkg.all;

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

    signal self                     : processor_with_ram_record   := init_processor(test_program'high);
    signal ram_read_instruction_in  : ram_read_in_record    ;
    signal ram_read_instruction_out : ram_read_out_record    ;
    signal ram_read_data_in         : ram_read_in_record    ;
    signal ram_read_data_out        : ram_read_out_record    ;
    signal ram_write_port           : ram_write_in_record   ;
    signal ram_write_port2          : ram_write_in_record   ;

    signal result       : real := 0.0;
    signal result2      : real := 0.0;
    signal result3      : real := 0.0;
    signal test_counter : natural := 0;

    signal state_counter : natural := 0;
    signal ram_control : ram_read_contorl_module_record := init_ram_read_module(ram_array'high, 0,0);

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

        variable ram_data : std_logic_vector(19 downto 0);
        constant register_memory_start_address : integer := ram_array'length-self.registers'length;
        constant zero : std_logic_vector(self.registers(0)'range) := (others => '0');
        variable used_instruction : std_logic_vector(self.instruction_pipeline(0)'range);

        function "+"
        (
            left, right : std_logic_vector 
        )
        return std_logic_vector 
        is
        begin
            return std_logic_vector(signed(left) + signed(right));
        end "+";


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
            -- save registers to ram
            if decode(self.instruction_pipeline(0)) = ready then
                save_registers(self, register_memory_start_address);
            end if;

            if self.register_read_counter < self.registers'length then
                self.register_read_counter <= self.register_read_counter + 1;
                self.read_address          <= self.read_address + 1;
                request_data_from_ram(ram_read_data_in, self.read_address);
            end if;

            if ram_read_is_ready(ram_read_data_out) then
                self.register_load_counter <= self.register_load_counter + 1;
                self.registers(self.register_load_counter) <= get_ram_data(ram_read_data_out);
            end if;

            if self.register_write_counter < self.registers'length then
                self.write_address          <= self.write_address + 1;
                self.register_write_counter <= self.register_write_counter + 1;
                write_data_to_ram(ram_write_port, self.write_address, self.registers(self.register_write_counter));
            end if;
        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            request_data_from_ram(ram_read_instruction_in, self.program_counter);
            ram_data := get_ram_data(ram_read_instruction_out);

            if ram_read_is_ready(ram_read_instruction_out) then
                self.instruction_pipeline <= ram_data & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
                if decode(ram_data) /= program_end then
                    self.program_counter <= self.program_counter + 1;
                end if;
            end if;

        ------------------------------------------------------------------------
            --stage 0
            used_instruction := self.instruction_pipeline(0);
        ------------------------------------------------------------------------
            --stage 1
            used_instruction := self.instruction_pipeline(1);

            CASE decode(used_instruction) is
                WHEN add =>
                    self.add_a <= self.registers(get_arg1(used_instruction));
                    self.add_b <= self.registers(get_arg2(used_instruction));
                WHEN sub =>
                    self.add_a <=  self.registers(get_arg1(used_instruction));
                    self.add_b <= not self.registers(get_arg2(used_instruction));
                WHEN mpy =>
                    self.mpy_a <= self.registers(get_arg1(used_instruction));
                    self.mpy_b <= self.registers(get_arg2(used_instruction));
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            --stage 2
            used_instruction := self.instruction_pipeline(2);

            self.add_result     <= self.add_a + self.add_b;
            self.mpy_raw_result <= signed(self.mpy_a) * signed(self.mpy_b);

        ------------------------------------------------------------------------
            --stage 3
            used_instruction := self.instruction_pipeline(3);
            
            self.mpy_result <= std_logic_vector(self.mpy_raw_result(38 downto 38-19));
        
            CASE decode(used_instruction) is
                WHEN add | sub =>
                    self.registers(get_dest(used_instruction)) <= self.add_result;
                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
            --stage 4
            used_instruction := self.instruction_pipeline(4);

            CASE decode(used_instruction) is
                WHEN mpy =>
                    self.registers(get_dest(used_instruction)) <= self.mpy_result;
                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
            --stage 5
            used_instruction := self.instruction_pipeline(5);

        ------------------------------------------------------------------------
            --stage 5

        ------------------------------------------------------------------------

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
    u_dpram : entity work.ram_read_x2_write_x1
    generic map(ram_contents)
    port map(
    simulator_clock          ,
    ram_read_instruction_in  ,
    ram_read_instruction_out ,
    ram_read_data_in         ,
    ram_read_data_out        ,
    ram_write_port);
------------------------------------------------------------------------
end vunit_simulation;
