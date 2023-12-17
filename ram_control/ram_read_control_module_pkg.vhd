library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.multi_port_ram_pkg.all;

package ram_read_control_module_pkg is

    constant number_of_ram_pipeline_cyles : natural := 3;

    type ram_read_contorl_module_record is record
        ram_data      : work.multi_port_ram_pkg.ramtype;
        stall_counter : natural range 0 to 127; -- this is arbitrary
        has_stalled   : boolean;
    end record;
------------------------------------------------------------------------
    function init_ram_read_module return ram_read_contorl_module_record;

    function init_ram_read_module (
        init1, init2, init3 : natural)
    return ram_read_contorl_module_record;

------------------------------------------------------------------------
    procedure create_ram_read_module (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        ram_read_out : in ram_read_out_record;
        increment : boolean);

-------

    procedure create_ram_read_module (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        ram_read_out : in ram_read_out_record);

------------------------------------------------------------------------
    function ram_data_is_ready (
        self : ram_read_contorl_module_record;
        ram_read_out : ram_read_out_record)
    return boolean;
----------------
    function ram_data_is_ready (
        self : ram_read_contorl_module_record;
        ram_read_out : ram_read_out_record)
    return std_logic;

------------------------------------------------------------------------
    function get_ram_data ( self : ram_read_contorl_module_record)
        return std_logic_vector;

------------------------------------------------------------------------
    procedure stall(
        signal self : inout ram_read_contorl_module_record; 
        signal ram_address   : inout natural range ram_array'range;
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27);

    procedure jump_to (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        address : natural);

    procedure jump_to (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27;
        address : natural);

------------------------------------------------------------------------
end package ram_read_control_module_pkg;

package body ram_read_control_module_pkg is

------------------------------------------------------------------------
    function init_ram_read_module
    return ram_read_contorl_module_record
    is
        variable retval : ram_read_contorl_module_record;
    begin
        retval := ((others => '0'), 0, false);
        return retval;
    end init_ram_read_module;
------------------------------------------------------------------------
    function init_ram_read_module
    (
        init1, init2, init3 : natural
    )
    return ram_read_contorl_module_record
    is
        variable retval : ram_read_contorl_module_record;
    begin
        retval := (std_logic_vector(to_unsigned(init1,ramtype'length)), init2, false);

        return retval;
        
    end init_ram_read_module;

------------------------------------------------------------------------
    procedure create_ram_read_module
    (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        ram_read_out : in ram_read_out_record;
        increment : boolean
    ) is
    begin
        ----------------
        if increment then
            if ram_address < ram_array'length-1 then
                ram_address <= ram_address + 1;
            else
                ram_address <= 0;
            end if;
        end if;
        ----------------

        if ram_read_is_ready(ram_read_out) then
            self.ram_data <= get_ram_data(ram_read_out);
        end if;

        if self.stall_counter = 0 and ram_read_is_ready(ram_read_out) then
            self.has_stalled   <= false;
        end if;

        if self.stall_counter > 0 then
            self.stall_counter <= self.stall_counter - 1;
            ram_address        <= ram_address;
            self.ram_data      <= self.ram_data;
        end if;
    end create_ram_read_module;
------------------------------
    procedure create_ram_read_module
    (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        ram_read_out : in ram_read_out_record
    ) is
    begin
        create_ram_read_module(self, ram_address, ram_read_out, true);
    end create_ram_read_module;

------------------------------------------------------------------------
    procedure stall(
        signal self : inout ram_read_contorl_module_record; 
        signal ram_address   : inout natural range ram_array'range;
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27)
    is
    begin
        if not self.has_stalled then
            ram_address        <= ram_address-number_of_ram_pipeline_cyles;
            self.stall_counter <= number_of_wait_cycles;
            self.has_stalled   <= true;
            self.ram_data      <= self.ram_data;
        end if;
    end stall;
------------------------------------------------------------------------
    procedure jump_to
    (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27;
        address : natural
    ) is
    begin
        stall(self, ram_address, number_of_wait_cycles);
        if not self.has_stalled then
            ram_address <= address;
        end if;

    end jump_to;
------------------------------
    procedure jump_to
    (
        signal self : inout ram_read_contorl_module_record;
        signal ram_address   : inout natural range ram_array'range;
        address : natural
    ) is
    begin
        jump_to(self, ram_address, 3, address);
        
    end jump_to;
------------------------------------------------------------------------
------------------------------------------------------------------------
    function ram_data_is_ready
    (
        self : ram_read_contorl_module_record;
        ram_read_out : ram_read_out_record
    )
    return boolean
    is
    begin
        return (not self.has_stalled) and ram_read_is_ready(ram_read_out);
    end ram_data_is_ready;

    function ram_data_is_ready
    (
        self : ram_read_contorl_module_record;
        ram_read_out : ram_read_out_record
    )
    return std_logic
    is
        variable retval : std_logic;
    begin
        if ram_data_is_ready(self, ram_read_out) then
            retval := '1';
        else
            retval := '0';
        end if;
        return retval;
    end ram_data_is_ready;

------------------------------------------------------------------------
    function get_ram_data
    (
        self : ram_read_contorl_module_record
    )
    return std_logic_vector
    is
    begin
        return self.ram_data;
    end get_ram_data;
------------------------------------------------------------------------


end package body ram_read_control_module_pkg;
