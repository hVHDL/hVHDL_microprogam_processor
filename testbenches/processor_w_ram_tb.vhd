library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

package ram_read_port_pkg is
    generic(ram_bit_width : natural;
            ram_depth     : natural);

    subtype address_integer is natural range 0 to ram_depth-1;
    subtype t_ram_data      is std_logic_vector(ram_bit_width-1 downto 0);

    type ram_read_port_record is record
        read_address             : address_integer;
        read_requested_with_1    : std_logic;
        data_is_ready_to_be_read : boolean;
        data                     : t_ram_data;
    end record;

    constant init_ram_read_port : ram_read_port_record := (0, '0', false, (others => '0'));

------------------------------------------------------------------------
    procedure create_ram_read_port (
        signal ram_read_object : inout ram_read_port_record);
------------------------------------------------------------------------
    procedure request_data_from_ram_and_increment (
        signal ram_read_counter : inout integer;
        signal ram_read_object : out ram_read_port_record;
        address : integer);
------------------------------------------------------------------------
    function ram_read_is_ready ( ram_read_object : ram_read_port_record)
        return boolean;
------------------------------------------------------------------------
    function get_ram_data ( ram_read_object : ram_read_port_record)
        return std_logic_vector;
------------------------------------------------------------------------
    procedure request_data_from_ram (
        signal ram_read_object : out ram_read_port_record;
        address : integer);
------------------------------------------------------------------------
    function get_read_pointer ( self : ram_read_port_record)
        return integer;
------------------------------------------------------------------------
    function read_is_requested ( self : ram_read_port_record)
        return boolean;
------------------------------------------------------------------------
end package ram_read_port_pkg;

------------------------------------------------------------------------
package body ram_read_port_pkg is

------------------------------------------------------------------------
    procedure create_ram_read_port
    (
        signal ram_read_object : inout ram_read_port_record
    ) is
    begin

        ram_read_object.read_requested_with_1    <= '0';
        ram_read_object.data_is_ready_to_be_read <= false;

        if ram_read_object.read_requested_with_1 = '1' then
            ram_read_object.data_is_ready_to_be_read <= ram_read_object.read_requested_with_1 = '1';
        end if;

    end create_ram_read_port;
------------------------------------------------------------------------
    function read_is_requested
    (
        self : ram_read_port_record
    )
    return boolean is
    begin
        return self.read_requested_with_1 = '1';
    end read_is_requested;
------------------------------------------------------------------------
    procedure request_data_from_ram
    (
        signal ram_read_object : out ram_read_port_record;
        address : integer
    ) is
    begin
        ram_read_object.read_requested_with_1 <= '1';
        ram_read_object.read_address <= address;
    end request_data_from_ram;
------------------------------------------------------------------------
    procedure request_data_from_ram_and_increment
    (
        signal ram_read_counter : inout integer;
        signal ram_read_object : out ram_read_port_record;
        address : integer
    ) is
    begin
        ram_read_counter <= ram_read_counter + 1;
        ram_read_object.read_requested_with_1 <= '1';
        ram_read_object.read_address <= address;
    end request_data_from_ram_and_increment;
------------------------------------------------------------------------
    function ram_read_is_ready
    (
        ram_read_object : ram_read_port_record
    )
    return boolean
    is
    begin
        return ram_read_object.data_is_ready_to_be_read;
    end ram_read_is_ready;
------------------------------------------------------------------------
    function get_ram_data
    (
        ram_read_object : ram_read_port_record
    )
    return std_logic_vector
    is
    begin
        return ram_read_object.data;
    end get_ram_data;
------------------------------------------------------------------------
    function get_read_pointer
    (
        self : ram_read_port_record
    )
    return integer
    is
    begin
        return self.read_address;
    end get_read_pointer;
------------------------------------------------------------------------
end package body ram_read_port_pkg;

------------------------------------------------------------------------
------------------------------------------------------------------------

LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 
    package ram_test_pkg is new work.ram_read_port_pkg generic map(ram_bit_width => 20, ram_depth => 31);

LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.NUMERIC_STD.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;
    
    use work.ram_test_pkg.all;
    use work.testprogram_pkg.all;
    use work.test_programs_pkg.all;

entity processor_w_ram_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of processor_w_ram_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    type test_array is array (integer range 0 to ram_depth-1) of std_logic_vector(ram_bit_width downto 0);
    signal ram_contents : test_array := (others => (others => '0'));

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
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
