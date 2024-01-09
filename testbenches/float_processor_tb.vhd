LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.simple_processor_pkg.all;
    use work.test_programs_pkg.build_sw;
    use work.real_to_fixed_pkg.all;
    use work.command_pipeline_pkg.all;

entity float_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of float_processor_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 10e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    ------------------------------------------------------------------------
    constant ram_contents : ram_array := build_sw(0.2);

    signal self                     : simple_processor_record := init_processor;
    signal command_pipeline         : command_pipeline_record := init_fixed_point_command_pipeline;
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal processor_is_ready : boolean := false;

    signal counter : natural range 0 to 7 :=7;
    signal counter2 : natural range 0 to 7 :=7;

    signal result1 : real := 0.0;
    signal result2 : real := 0.0;
    signal result3 : real := 0.0;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        check(result1 > 0.45 and result1 < 0.55);
        check(result2 > 0.45 and result2 < 0.55);
        check(result3 > 0.45 and result3 < 0.55);
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
            create_simple_processor (
                self                     ,
                ram_read_instruction_in  ,
                ram_read_instruction_out ,
                ram_read_data_in         ,
                ram_read_data_out        ,
                ram_write_port           ,
                used_instruction);

            create_command_pipeline(
                command_pipeline          ,
                ram_read_instruction_in   ,
                ram_read_instruction_out  ,
                ram_read_data_in          ,
                ram_read_data_out         ,
                ram_write_port            ,
                self.registers            ,
                self.instruction_pipeline ,
                used_instruction);
    ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            if simulation_counter mod 60 = 0 then
                request_processor(self);
            end if;
        ------------------------------------------------------------------------
        -- test signals
        ------------------------------------------------------------------------
            processor_is_ready <= program_is_ready(self);
            if program_is_ready(self) then
                counter <= 0;
                counter2 <= 0;
            end if;
            if counter < 7 then
                counter <= counter +1;
            end if;

            CASE counter is
                WHEN 0 => request_data_from_ram(ram_read_data_in, 101);
                WHEN 1 => request_data_from_ram(ram_read_data_in, 104);
                WHEN 2 => request_data_from_ram(ram_read_data_in, 106);
                WHEN others => --do nothing
            end CASE;
            if not processor_is_enabled(self) then
                if ram_read_is_ready(ram_read_data_out) then
                    counter2 <= counter2 + 1;
                    CASE counter2 is
                        WHEN 0 => result1 <= to_real(get_ram_data(ram_read_data_out),19);
                        WHEN 1 => result2 <= to_real(get_ram_data(ram_read_data_out),19);
                        WHEN 2 => result3 <= to_real(get_ram_data(ram_read_data_out),19);
                        WHEN others => -- do nothing
                    end CASE; --counter2
                end if;
            end if;


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
