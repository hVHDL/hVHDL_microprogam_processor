LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.microcode_processor_pkg.all;
    use work.multi_port_ram_pkg.all;

entity test_jump_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of test_jump_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 5e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------

    constant reg_offset : natural := work.ram_configuration_pkg.ram_array'high;
------------------------------------------------------------------------

    constant load_save_address_from_register_5 : natural := 5;

    constant program : program_array := (
        write_instruction(set, 7, 6),
        write_instruction(jump_indirect) ,
        write_instruction(nop)           ,
        write_instruction(nop)           ,
        write_instruction(nop)           ,
        write_instruction(nop)           ,
        write_instruction(load         , 0  , 101) ,
        write_instruction(load         , 1  , 102) ,
        write_instruction(load         , 2  , 103) ,
        write_instruction(load         , 3  , 104) ,
        write_instruction(nop)         ,
        write_instruction(load         , 4  , 105) ,
        write_instruction(nop)         ,
        write_instruction(load         , 5  , 106) ,
        write_instruction(load         , 6  , 107) ,
        write_instruction(save         , 0  , 107) ,
        write_instruction(save         , 1  , 106) ,
        write_instruction(save         , 2  , 105) ,
        write_instruction(save         , 4  , 104) ,
        write_instruction(save         , 3  , 103) ,
        write_instruction(save         , 5  , 102) ,
        write_instruction(save         , 6  , 101) ,
        write_instruction(stall        , 5) ,
        write_instruction(set          , 5  , 6)   ,
        write_instruction(set          , 6  , 7)   ,
        write_instruction(set          , 8  , 9)   ,
        write_instruction(nop)         ,
        write_instruction(program_end) ,
        write_instruction(set          , 8  , 9)   ,
        write_instruction(nop)         ,
        write_instruction(nop)         ,
        write_instruction(nop)         ,
        write_instruction(nop)         ,
        write_instruction(nop)     
    );
------------------------------------------------------------------------

------------------------------------------------------------------------
    function init_ram_data_with_indices return ram_array
    is
        variable retval : ram_array;
    begin

        for i in retval'range loop
            retval(i) := std_logic_vector(to_unsigned(i,retval(0)'length));
        end loop;

        return retval;
        
    end init_ram_data_with_indices;

    function build_sw return ram_array
    is
        variable retval : ram_array := init_ram_data_with_indices;
    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;
            
        return retval;
        
    end build_sw;
------------------------------------------------------------------------

    constant ram_contents : ram_array := build_sw;

    signal self                     : processor_with_ram_record := init_processor(100, false);
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

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
    ------------------------------------------------------------------------
        variable used_instruction : t_instruction;

        procedure request_program is
        begin
            self.program_counter <= 0;
            self.processor_enabled <= true;
        end request_program;


    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
        --------------------------------------------------
        ------------------------------------------------------------------------
            --stage -1

            if self.processor_enabled then
                request_data_from_ram(ram_read_instruction_in, self.program_counter);

                if ram_read_is_ready(ram_read_instruction_out) then
                    used_instruction := get_ram_data(ram_read_instruction_out);
                end if;

                if decode(used_instruction) = program_end then
                    self.processor_enabled <= false;
                    used_instruction := write_instruction(nop);
                else
                    self.program_counter <= self.program_counter + 1;
                end if;
            else
                used_instruction := write_instruction(nop);
            end if;


            CASE decode(used_instruction) is
                WHEN load =>
                    request_data_from_ram(ram_read_data_in, get_sigle_argument(used_instruction));

                WHEN stall =>
                    self.stall_counter   <= get_long_argument(used_instruction);
                    self.program_counter <= self.program_counter - 3;
                    used_instruction := write_instruction(nop);

                WHEN write_pc =>
                    self.registers(0) <= std_logic_vector(to_unsigned(self.program_counter-3,self.registers(0)'length));
                WHEN others => -- do nothing
            end CASE;


            if self.stall_counter > 0 then
                self.stall_counter   <= self.stall_counter - 1;
                self.program_counter <= self.program_counter;
                used_instruction := write_instruction(nop);
            end if;

            self.instruction_pipeline <= used_instruction & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            --stage 0
            used_instruction := self.instruction_pipeline(0);

            CASE decode(used_instruction) is
                WHEN add =>
                    self.add_a <= self.registers(get_arg1(used_instruction));
                    self.add_b <= self.registers(get_arg2(used_instruction));
                WHEN sub =>
                    self.add_a <=  self.registers(get_arg1(used_instruction));
                    self.add_b <= -self.registers(get_arg2(used_instruction));
                WHEN mpy =>
                    self.mpy_a <= self.registers(get_arg1(used_instruction));
                    self.mpy_b <= self.registers(get_arg2(used_instruction));
                WHEN set =>
                    self.registers(get_dest(used_instruction)) <= get_sigle_argument(used_instruction);

                WHEN load_registers =>
                    load_registers(self, get_long_argument(self.instruction_pipeline(0)));

                WHEN jump =>
                    self.program_counter <= get_long_argument(self.instruction_pipeline(0));

                WHEN jump_indirect =>
                    self.program_counter <= to_integer(unsigned(self.registers(7)));

                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            --stage 1
            used_instruction := self.instruction_pipeline(1);
        ------------------------------------------------------------------------
            --stage 2
            used_instruction := self.instruction_pipeline(2);
            CASE decode(used_instruction) is
                WHEN load =>
                    self.registers(get_dest(used_instruction)) <= get_ram_data(ram_read_data_out);

                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
            --stage 3
            used_instruction := self.instruction_pipeline(3);
            CASE decode(used_instruction) is
                WHEN save =>
                    write_data_to_ram(ram_write_port, get_sigle_argument(used_instruction), self.registers(get_dest(used_instruction)));

                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            --stage 4
            used_instruction := self.instruction_pipeline(4);
        ------------------------------------------------------------------------
            --stage 5
            used_instruction := self.instruction_pipeline(5);
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            if simulation_counter = 20 then
                request_program;
            end if;
        ------------------------------------------------------------------------
        -- test signals
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
