LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

package generic_ram_connector_pkg is
    generic(
            package connector_mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
            );
    use connector_mp_ram_pkg.all;

    type ram_connector_record is record
        read_in  : ram_read_in_array;
        read_out : ram_read_out_array;
    end record;

    procedure init_ram_connector(signal self : inout ram_connector_record);
    procedure connect_data_to_ram_bus(
                     signal self : inout ram_connector_record
                     ; ram_port_in : in ram_read_in_array
                     ; signal ram_port_out : out ram_read_out_array
                     ; address : in natural
                     ; data : in ramtype);

    -------------------------------------------
    procedure generic_connect_ram_write_to_address
    generic( type return_type
            ;function conv(a : std_logic_vector) return return_type is <>)
    (
        write_in : in ram_write_in_record
        ; address : in natural
        ; signal data : out return_type
    ) ;

    -------------------------------------------
    procedure connect_ram_write_to_address
    (
        write_in : in ram_write_in_record
        ; address : in natural
        ; signal data : out std_logic_vector
    );
    -------------------------------------------

end package generic_ram_connector_pkg;

package body generic_ram_connector_pkg is

    -------------------------------------------
    procedure init_ram_connector(signal self : inout ram_connector_record) is
    begin
        for i in self.read_out'range loop
                self.read_out(i).data <= (others => '0');
                self.read_out(i).data_is_ready <= '0';
        end loop;
    end init_ram_connector;

    -------------------------------------------
    procedure connect_data_to_ram_bus(
                     signal self : inout ram_connector_record
                     ; ram_port_in : in ram_read_in_array
                     ; signal ram_port_out : out ram_read_out_array
                     ; address : in natural
                     ; data : in ramtype
                 ) is
    begin
        for i in ram_port_in'range loop
            if read_requested(ram_port_in(i), address) then
                self.read_out(i).data <= data;
                self.read_out(i).data_is_ready <= '1';
            end if;
        end loop;

        ram_port_out <= self.read_out;

    end connect_data_to_ram_bus;

    ----------------------------------
    -- this does not seem to work properly from package for some reason :(
    procedure generic_connect_ram_write_to_address
    generic( type return_type
            ;function conv(a : std_logic_vector) return return_type is <>)
    (
        write_in : in ram_write_in_record
        ; address : in natural
        ; signal data : out return_type
    ) 
    is
    begin
        if write_requested(write_in,address) then
            data <= conv(get_data(write_in));
        end if;
    end generic_connect_ram_write_to_address;

    -------------------------------------------
    procedure connect_ram_write_to_address
    (
        write_in : in ram_write_in_record
        ; address : in natural
        ; signal data : out std_logic_vector
    ) is
    begin
        if write_requested(write_in,address) then
            data <= get_data(write_in);
        end if;
    end connect_ram_write_to_address;

end package body generic_ram_connector_pkg;
