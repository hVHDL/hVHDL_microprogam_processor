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
    use work.ram_port_pkg.all;

entity tb_stall_pipeline is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of tb_stall_pipeline is

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

    signal result       : real := 0.0;
    signal result2      : real := 0.0;
    signal result3      : real := 0.0;
    signal test_counter : natural := 0;

    signal state_counter : natural := 0;
    signal ram_address : natural range 0 to ram_array'length := 0;

    signal ram_data : natural := ram_array'length + 11;

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
        variable stall_pipeline : boolean := false;
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------

            stall_pipeline := ram_read_is_ready(ram_read_instruction_out) AND
                             (get_uint_ram_data(ram_read_instruction_out) mod 3 = 0);

            if ram_address < ram_array'length-1 then
                ram_address <= ram_address + 1;
            else
                ram_address <= 0;
            end if;

            if ram_read_is_ready(ram_read_instruction_out) then
                ram_data <= get_uint_ram_data(ram_read_instruction_out);
            end if;

            if not stall_pipeline then
                request_data_from_ram(ram_read_instruction_in, ram_address);
            end if;


        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
    u_dpram : entity work.dual_port_ram
    generic map(ram_contents)
    port map(
    simulator_clock          ,
    ram_read_instruction_in  ,
    ram_read_instruction_out ,
    ram_write_port           ,
    ram_read_data_in         ,
    ram_read_data_out        ,
    ram_write_port2);
------------------------------------------------------------------------
end vunit_simulation;
