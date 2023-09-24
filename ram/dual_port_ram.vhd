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
        -- clka  : in std_logic;                                       -- Clock
        -- addra : in std_logic_vector((logb2(RAM_DEPTH)-1) downto 0); -- Port A Address
        -- ena   : in std_logic;                                       -- Port A RAM Enable
        -- wea   : in std_logic;                                       -- Port A Write enable
        -- dina  : in std_logic_vector(RAM_WIDTH-1 downto 0);          -- Port A RAM input data
        -- rsta  : in std_logic;                                       -- Port A Output reset
        -- regcea: in std_logic;                                       -- Port A Output register enable
        -- douta : out std_logic_vector(RAM_WIDTH-1 downto 0);         -- Port A RAM output data

        -- addrb : in std_logic_vector((logb2(RAM_DEPTH)-1) downto 0);     -- Port B Address
        -- dinb  : in std_logic_vector(RAM_WIDTH-1 downto 0);		-- Port B RAM input data
        -- web   : in std_logic;                       			-- Port B Write enable
        -- enb   : in std_logic;                       			-- Port B RAM Enable
        -- rstb  : in std_logic;                       			-- Port B Output reset 
        -- regceb: in std_logic;                       			-- Port B Output register enable
        -- doutb : out std_logic_vector(RAM_WIDTH-1 downto 0)   		-- Port B RAM output data



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
------------------------------------------------------------------------
    alias ram_data_array is ram_array;

------------------------------------------------------------------------
    type dp_ram is protected

    ------------------------------
        procedure write_ram(
            address : in natural;
            data :    in std_logic_vector);
    ------------------------------
        impure function read_data(address : natural)
            return std_logic_vector;
    ------------------------------

    end protected dp_ram;

------------------------------------------------------------------------
    type dp_ram is protected body
    ------------------------------
        impure function init_ram
        (
            ram_init_values : ram_array
        )
        return ram_data_array
        is
            variable retval : ram_data_array := (others => (others => '0'));
        begin

            for i in ram_init_values'range loop
                retval(i) := ram_init_values(i);
            end loop;

            return retval;
            
        end init_ram;

        variable ram_contents : ram_data_array := init_ram(init_program);

    ------------------------------
        impure function read_data
        (
            address : natural
        )
        return std_logic_vector 
        is
        begin
            return ram_contents(address);
        end read_data;

    ------------------------------
        procedure write_ram
        (
            address : in natural;
            data    : in std_logic_vector
        ) is
        begin
            ram_contents(address) := data;
        end write_ram;


    ------------------------------
    end protected body;
------------------------------------------------------------------------

    shared variable dual_port_ram_array : dp_ram;

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
