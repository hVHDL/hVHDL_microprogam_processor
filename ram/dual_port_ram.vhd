library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package ram_port_pkg is

    -- move these to separate package
    subtype ramtype is std_logic_vector(19 downto 0);
    subtype ram_address is std_logic_vector(5 downto 0);

    type ram_read_in_record is record
        address : ram_address;
        read_is_requested : std_logic;
    end record;

    type ram_read_out_record is record
        data          : std_logic_vector(ramtype'range);
        data_is_ready : std_logic;
    end record;

    type ram_write_in_record is record
        data : std_logic_vector(ramtype'range);
        write_requested : std_logic;
    end record;

end package ram_port_pkg;

package body ram_port_pkg is

end package body ram_port_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.ram_port_pkg.all;

entity dual_port_ram is
    generic(init_program : ram_array);
    port (
        clock : in std_logic;
        ram_read_a_in  : in ram_read_in_record;
        ram_read_a_out : out ram_read_out_record;
        ram_write_a_in : in ram_write_in_record;
        --------------------
        ram_read_b_in  : in ram_read_in_record;
        ram_read_b_out : out ram_read_out_record;
        ram_write_b_in : in ram_write_in_record
    );
end entity dual_port_ram;

architecture rtl of dual_port_ram is

    signal ram_read_port_a  : ram_read_port_record   := init_ram_read_port  ;
    signal ram_write_port_a : ram_write_port_record  := init_ram_write_port ;

    signal ram_read_port_b  : ram_read_port_record   := init_ram_read_port  ;
    signal ram_write_port_b : ram_write_port_record  := init_ram_write_port ;

    signal ram_contents : ram_array := init_program;

begin

    create_ram : process(clock, ram_read_a_in, ram_read_b_in)
    begin
        if rising_edge(clock) then
            create_ram_read_port(ram_read_port_a);
            create_ram_read_port(ram_read_port_b);
            create_ram_write_port(ram_write_port_b);
            create_ram_write_port(ram_write_port_b);
            --------------------
            if read_is_requested(ram_read_port_a) then
                ram_read_port_a.data <= ram_contents(get_ram_address(ram_read_port_a));
            end if;
            --------------------
            if read_is_requested(ram_read_port_b) then
                ram_read_port_b.data <= ram_contents(get_ram_address(ram_read_port_b));
            end if;
            --------------------
            if write_is_requested(ram_write_port_a) then
                ram_contents(get_write_address(ram_write_port_a)) <= ram_write_port_a.write_buffer;
            end if;
            --------------------
            if write_is_requested(ram_write_port_b) then
                ram_contents(get_write_address(ram_write_port_b)) <= ram_write_port_b.write_buffer;
            end if;
        end if; --rising_edge
    end process create_ram;	

end rtl;
