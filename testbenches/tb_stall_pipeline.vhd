------------------------------------------------------------------------
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

entity tb_stall_pipeline is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_stall_pipeline is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 150;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
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

    signal ram_read_instruction_in  : ram_read_in_record  ;
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  ;
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal self : ram_read_contorl_module_record := init_ram_read_module(ram_array'high, 0,0);

    signal instruction_pipeline : instruction_array := (others => (others => '0'));
    signal increment : boolean := true;

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
        variable used_instruction : t_instruction;
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
            create_ram_read_module(
                self         => self                     ,
                ram_read_out => ram_read_instruction_out ,
                increment    => true);

            if decode(used_instruction) = program_end then
                -- stall(self, 3);
                -- increment <= false;
            end if;

            -- if self.flush_counter = 0 and (decode(used_instruction) /= program_end) then
                -- request_data_from_ram(ram_read_instruction_in, self.ram_address);
            -- end if;

            if ram_data_is_ready(self, ram_read_instruction_out) then
            end if;

            instruction_pipeline <= get_ram_data(self) & instruction_pipeline(0 to instruction_pipeline'high-1);
            used_instruction := get_ram_data(self);
            CASE decode(used_instruction) is
                WHEN program_end =>
                    -- jump_to(self.address, self.address-4);
                    
                WHEN others => --do nothing
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
