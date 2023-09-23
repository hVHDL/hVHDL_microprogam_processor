library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package dual_port_ram_pkg is

    type ram_read_in_record is record
        address : std_logic_vector(9 downto 0);
        data    : std_logic_vector(31 downto 0);
        read_is_requested : boolean;
    end record;

    type ram_read_out_record is record
        data : std_logic;
        data_is_ready : boolean;
    end record;

    type ram_write_in_record is record
        write_requested : std_logic;
        data : std_logic_vector(31 downto 0);
    end record;

end package dual_port_ram_pkg;

package body dual_port_ram_pkg is

end package body dual_port_ram_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.dual_port_ram_pkg.all;

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
