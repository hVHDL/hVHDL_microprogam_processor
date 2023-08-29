library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ram_configuration_pkg is

    constant ram_bit_width : natural := 20;
    constant ram_depth     : natural := 32;

end package ram_configuration_pkg;
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

    use work.ram_configuration_pkg.all;

package ram_read_pkg is

    alias ram_bit_width is ram_bit_width;
    alias ram_depth is ram_depth;

    subtype address_integer is natural range 0 to ram_depth-1;
    subtype t_ram_data      is std_logic_vector(ram_bit_width-1 downto 0);

    type ram_array is array (integer range 0 to ram_depth-1) of t_ram_data;

    type ram_read_port_record is record
        read_address   : address_integer;
        ready_pipeline : std_logic_vector(1 downto 0);
        data           : t_ram_data;
    end record;

    constant init_ram_read_port : ram_read_port_record := (0, (others => '0'), (others => '0'));

------------------------------------------------------------------------
    procedure create_ram_read_port (
        signal self : inout ram_read_port_record);
------------------------------------------------------------------------
    procedure request_data_from_ram_and_increment (
        signal ram_read_counter : inout integer;
        signal self : out ram_read_port_record;
        address : integer);
------------------------------------------------------------------------
    function ram_read_is_ready ( self : ram_read_port_record)
        return boolean;
------------------------------------------------------------------------
    function get_ram_data ( ram_read_object : ram_read_port_record)
        return std_logic_vector;
------------------------------------------------------------------------
    procedure request_data_from_ram (
        signal self : out ram_read_port_record;
        address : integer);
------------------------------------------------------------------------
    function get_ram_address ( self : ram_read_port_record)
        return integer;
------------------------------------------------------------------------
    function read_is_requested ( self : ram_read_port_record)
        return boolean;
------------------------------------------------------------------------
end package ram_read_pkg;

------------------------------------------------------------------------
package body ram_read_pkg is

------------------------------------------------------------------------
    procedure create_ram_read_port
    (
        signal self : inout ram_read_port_record
    ) is
    begin
        self.ready_pipeline <= self.ready_pipeline(self.ready_pipeline'left -1 downto 0) & '0';

    end create_ram_read_port;
------------------------------------------------------------------------
    function read_is_requested
    (
        self : ram_read_port_record
    )
    return boolean is
    begin
        return self.ready_pipeline(0) = '1';
    end read_is_requested;
------------------------------------------------------------------------
    procedure request_data_from_ram
    (
        signal self : out ram_read_port_record;
        address : integer
    ) is
    begin
        self.ready_pipeline(0) <= '1';
        self.read_address <= address;
    end request_data_from_ram;
------------------------------------------------------------------------
    procedure request_data_from_ram_and_increment
    (
        signal ram_read_counter : inout integer;
        signal self : out ram_read_port_record;
        address : integer
    ) is
    begin
        ram_read_counter <= ram_read_counter + 1;
        self.ready_pipeline(1) <= '1';
        self.read_address <= address;
    end request_data_from_ram_and_increment;
------------------------------------------------------------------------
    function ram_read_is_ready
    (
        self : ram_read_port_record
    )
    return boolean
    is
    begin
        return self.ready_pipeline(self.ready_pipeline'left) = '1';
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
    function get_ram_address
    (
        self : ram_read_port_record
    )
    return integer
    is
    begin
        return self.read_address;
    end get_ram_address;
------------------------------------------------------------------------
end package body ram_read_pkg;
