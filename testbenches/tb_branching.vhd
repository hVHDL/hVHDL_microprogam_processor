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

entity tb_branching is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_branching is

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

    constant ram_contents : ram_array := 
        write_register_values_to_ram(
        write_register_values_to_ram(
        write_register_values_to_ram(
            init_ram(test_program), 
            to_fixed((0.0 , 0.44252 , 0.1   , 0.1   , 0.1   , 0.1   , 0.1   , 0.0104166 , 0.1)   , 19) , 53-reg_array'length*0)  ,
            to_fixed((0.0 , 0.44252 , 0.2   , 0.2   , 0.2   , 0.2   , 0.2   , 0.0804166 , 0.2)   , 19) , 53-reg_array'length*1)  ,
            to_fixed((0.0 , 0.44252 , -0.99 , -0.99 , -0.99 , -0.99 , -0.99 , 0.1804166 , -0.99) , 19) , 53-reg_array'length*2);

    function test_function_calls
    return program_array
    is
        constant program : program_array := (
            write_instruction(load_registers, 53-reg_array'length*0),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(nop),
            write_instruction(jump, dummy'length));
    begin
        return program;
        
    end test_function_calls;

    signal self                     : processor_with_ram_record := init_processor(test_program'high);
    signal ram_read_instruction_in  : ram_read_in_record  ;
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  ;
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal result       : real := 0.0;
    signal result2      : real := 0.0;
    signal result3      : real := 0.0;
    signal test_counter : natural := 0;

    signal state_counter : natural := 0;
    signal ram_read_control : ram_read_contorl_module_record := init_ram_read_module(ram_array'high, 0,0);

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
            create_processor_w_ram(
                self                     ,
                ram_read_instruction_in  ,
                ram_read_instruction_out ,
                ram_read_data_in         ,
                ram_read_data_out        ,
                ram_write_port           ,
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
                    if program_is_ready(self) then
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
