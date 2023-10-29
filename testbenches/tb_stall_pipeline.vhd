library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.multi_port_ram_pkg.all;

package ram_read_control_module_pkg is

    constant number_of_ram_pipeline_cyles : natural := 3;

    type ram_read_contorl_module_record is record
        ram_data      : work.multi_port_ram_pkg.ramtype;
        ram_address   : natural;
        flush_counter : natural;
        has_stalled : boolean;
    end record;
------------------------------------------------------------------------
    function init_ram_read_module (
        init1, init2, init3 : natural)
    return ram_read_contorl_module_record;

------------------------------------------------------------------------
    procedure create_ram_read_module (
        signal self : inout ram_read_contorl_module_record;
        ram_read_out : in ram_read_out_record);

------------------------------------------------------------------------
    procedure stall(
        signal self : inout ram_read_contorl_module_record; 
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27);

------------------------------------------------------------------------
end package ram_read_control_module_pkg;

package body ram_read_control_module_pkg is

------------------------------------------------------------------------
    function init_ram_read_module
    (
        init1, init2, init3 : natural
    )
    return ram_read_contorl_module_record
    is
        variable retval : ram_read_contorl_module_record;
    begin
        retval := (std_logic_vector(to_unsigned(init1,ramtype'length)), init2, init3, false);

        return retval;
        
    end init_ram_read_module;
------------------------------------------------------------------------
    procedure create_ram_read_module
    (
        signal self : inout ram_read_contorl_module_record;
        ram_read_out : in ram_read_out_record
    ) is
    begin
        ----------------
        if ram_read_is_ready(ram_read_out) then
            self.ram_data <= get_ram_data(ram_read_out);
        end if;

        ----------------
        if self.ram_address < ram_array'length-1 then
            self.ram_address <= self.ram_address + 1;
        else
            self.ram_address <= 0;
        end if;
        ----------------

        if self.flush_counter = 0 and ram_read_is_ready(ram_read_out) then
            self.has_stalled   <= false;
        end if;
        if self.flush_counter > 0 then
            self.flush_counter <= self.flush_counter - 1;
            self.ram_address   <= self.ram_address;
            self.ram_data      <= self.ram_data;
        end if;
    end create_ram_read_module;

------------------------------------------------------------------------
    procedure stall(
        signal self : inout ram_read_contorl_module_record; 
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27)
    is
    begin
        if not self.has_stalled then
            self.ram_address   <= self.ram_address-number_of_ram_pipeline_cyles;
            self.flush_counter <= number_of_wait_cycles;
            self.has_stalled   <= true;
            self.ram_data      <= self.ram_data;
        end if;
    end stall;
------------------------------------------------------------------------

end package body ram_read_control_module_pkg;

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
    function init_ram_array_w_indices
    return ram_array
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
    signal ram_data      : natural := ram_array'high;
    signal ram_address   : natural := 0;
    signal flush_counter : natural := 0;

    signal ram_data_delayed : natural := ram_array'high;

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
                WHEN 15 => stall(self, 5);
                WHEN 27 => stall(self, 8);
                WHEN 31 => stall(self, number_of_ram_pipeline_cyles);
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
            ram_data_delayed <= to_integer(self.ram_data);
            if to_integer(self.ram_data) /= ram_data_delayed then
                if to_integer(self.ram_data) /= 0 then
                    check(to_integer(self.ram_data) - ram_data_delayed = 1);
                end if;
            end if;

            -- log for gtkwave
            ram_data      <= to_integer(self.ram_data);
            ram_address   <= self.ram_address;
            flush_counter <= self.flush_counter;

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
