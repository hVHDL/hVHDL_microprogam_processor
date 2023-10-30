LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.multi_port_ram_pkg.all;
    use work.ram_read_control_module_pkg.all;

entity tb_ram_control_ready is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_ram_control_ready is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 150;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    function init_ram_array_w_indices return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
    begin

        for i in retval'range loop
            retval(i) := std_logic_vector(to_unsigned(i, retval(0)'length));
        end loop;

        return retval;

    end init_ram_array_w_indices;

    constant ram_contents : ram_array := init_ram_array_w_indices;

    signal ram_read_instruction_in  : ram_read_in_record  ;
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  ;
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal self : ram_read_contorl_module_record := init_ram_read_module(ram_array'high, 0,0);
    signal ram_data      : natural := 0;
    signal ram_address   : natural := 0;
    signal flush_counter : natural := 0;

    signal ram_is_ready : boolean := false;

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
        function to_integer
        (
            data : ramtype
        )
        return integer
        is
        begin
            return to_integer(unsigned(data));
        end to_integer;
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
            create_ram_read_module(self, ram_read_instruction_out);

            if self.flush_counter = 0 then
                request_data_from_ram(ram_read_instruction_in, self.ram_address);
            end if;

            CASE to_integer(self.ram_data) is
                WHEN 15 => 
                    jump_to(self, 27);
                WHEN 27 => jump_to(self, 8, 31);
                WHEN 31 => jump_to(self, 8, 32);
                WHEN 32 => stall(self, number_of_ram_pipeline_cyles);
                WHEN 33 => stall(self, 8);
                WHEN 34 => stall(self, 15);
                WHEN 35 => stall(self, number_of_ram_pipeline_cyles);
                WHEN 44 => stall(self, number_of_ram_pipeline_cyles);
                WHEN others => --do nothing
            end CASE;
    ------------------------------------------------------------------------
    ----------- test -------------------------------------------------------

            -- test for correct sequence
            if ram_data_is_ready(self, ram_read_instruction_out) then
                ram_data <= to_integer(self.ram_data);
                check(ram_data /= to_integer(self.ram_data));
            end if;
            ram_is_ready  <= ram_data_is_ready(self, ram_read_instruction_out);

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
