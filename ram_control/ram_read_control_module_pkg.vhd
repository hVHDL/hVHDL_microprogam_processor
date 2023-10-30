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
        ram_read_out : in ram_read_out_record);

    function ram_data_is_ready (
        self : ram_read_contorl_module_record;
        ram_read_out : ram_read_out_record)
    return boolean;

------------------------------------------------------------------------
    procedure stall(
        signal self : inout ram_read_contorl_module_record; 
        number_of_wait_cycles : in natural range number_of_ram_pipeline_cyles to 27);

    procedure jump_to (
        signal self : inout ram_read_contorl_module_record;
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
        retval := ((others => '0'), 0,0, false);
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
    procedure jump_to
    (
        signal self : inout ram_read_contorl_module_record;
        address : natural
    ) is
    begin
        stall(self, 3);
        if not self.has_stalled then
            self.ram_address <= address;
        end if;
        
    end jump_to;
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
------------------------------------------------------------------------

end package body ram_read_control_module_pkg;

