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

entity tb_branching is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_branching is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------

    constant dummy      : program_array := get_dummy;
    constant reg_offset : natural := work.ram_configuration_pkg.ram_array'high;
------------------------------------------------------------------------
    constant load_save_address_from_register_5 : natural := 5;

    function test_function_calls return program_array
    is
        constant program : program_array := (
            write_instruction(load_registers, reg_offset-reg_array'length*0),
            write_instruction(stall, 12),
            write_instruction(set, 5, reg_offset-reg_array'length*0),
            write_instruction(set      , 6  , 1) ,
            write_instruction(write_pc , 7) ,
            write_instruction(jump     , 0) ,
            write_instruction(nop)     ,
            write_instruction(nop)     ,
            write_instruction(nop)     ,
            write_instruction(nop)     ,
            write_instruction(nop)     ,
            write_instruction(nop)     
        );
    begin
        return program;
        
    end test_function_calls;
------------------------------------------------------------------------

    constant low_pass_filter : program_array := get_pipelined_low_pass_filter;
    constant function_calls  : program_array := test_function_calls;

    constant test_program    : program_array := 
        get_pipelined_low_pass_filter                                                                                &
        write_instruction(save_registers_indirect, load_save_address_from_register_5, reg_offset-reg_array'length*2) &
        write_instruction(stall, 12)                                                                                 &
        write_instruction(jump_indirect, 7)                                                                          &
        get_dummy                                                                                                    &
        function_calls
        ;

------------------------------------------------------------------------
    function build_sw return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
        constant reg_values1 : reg_array := to_fixed((0.0 , 0.44252 , 0.0 , 0.1804166) , 19);
        constant reg_values2 : reg_array := to_fixed((0.0 , 0.44252 , 0.0 , 0.1204167) , 19);
        constant reg_values3 : reg_array := to_fixed((0.0 , 0.44252 , 0.0 , 0.0804166) , 19);
    begin

        retval := write_register_values_to_ram(init_ram(test_program) , reg_values1 , reg_offset-reg_array'length*2);
        retval := write_register_values_to_ram(retval                 , reg_values2 , reg_offset-reg_array'length*1);
        retval := write_register_values_to_ram(retval                 , reg_values3 , reg_offset-reg_array'length*0);
            
        return retval;
        
    end build_sw;
------------------------------------------------------------------------

    constant ram_contents : ram_array := build_sw;

    signal self                     : processor_with_ram_record := init_processor(100);
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal result       : real    := 0.0;
    signal result2      : real    := 0.0;
    signal result3      : real    := 0.0;
    signal test_counter : natural := 0;

    signal state_counter : natural := 0;

    signal register_load_command_was_hit   : boolean := false;
    signal jump_was_hit                    : boolean := false;
    signal stall_was_hit                   : boolean := false;
    signal save_registers_indirect_was_hit : boolean := false;

    signal jump_indirect_was_hit : boolean := false;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(register_load_command_was_hit);
        check(jump_was_hit);
        check(stall_was_hit, "stall was not hit");
        check(save_registers_indirect_was_hit,  "save registers was not hit");
        check(jump_indirect_was_hit,  "jump_indirct was not hit");
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
    ------------------------------------------------------------------------
        procedure request_low_pass_filter is
            constant temp : program_array := (get_pipelined_low_pass_filter & get_dummy);
        begin
            self.program_counter <= temp'length + 1;
        end request_low_pass_filter;
    ------------------------------------------------------------------------

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
            if simulation_counter > 30 then
                CASE state_counter is
                    WHEN 0 => 
                        state_counter <= state_counter+1;
                        request_low_pass_filter;
                    WHEN 1 =>
                        if program_is_ready(self) then
                            CASE get_register_value(self, 6) is
                                WHEN 2 => result2     <= to_real(signed(self.registers(0)),self.registers(0)'length-1);
                                WHEN 3 => result3     <= to_real(signed(self.registers(0)),self.registers(0)'length-1);
                                WHEN others => result <= to_real(signed(self.registers(0)),self.registers(0)'length-1);
                            end CASE;
                            state_counter <= state_counter+1;
                        end if;
                    WHEN 2 =>
                        if register_write_ready(self) then
                            load_registers(self, 15);
                            state_counter <= state_counter+1;
                        end if;
                    WHEN 3 =>
                        if register_load_ready(self) then
                            state_counter <= 0;
                        end if;
                    WHEN others => -- do nothing
                end CASE;
            end if;
        ------------------------------------------------------------------------
        -- test signals
            CASE decode(get_ram_data(ram_read_instruction_out)) is
                WHEN load_registers => register_load_command_was_hit            <= true;
                WHEN jump           => jump_was_hit                             <= true;
                WHEN stall          => stall_was_hit                            <= true;
                WHEN save_registers_indirect => save_registers_indirect_was_hit <= true;
                WHEN jump_indirect => jump_indirect_was_hit <= true;

                WHEN others => --do nothing
            end CASE;
        ------------------------------------------------------------------------

        end if; -- rising_edge
    end process stimulus;	

------------------------------------------------------------------------
    u_mpram : entity work.ram_read_x2_write_x1
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
