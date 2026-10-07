
library ieee;
    use ieee.std_logic_1164.all;

package microprogram_interface_pkg is

    type microprogram_processor_in_record is record
        processor_requested  : boolean;
        start_address        : natural;
    end record;

    type microprogram_processor_out_record is record
        is_busy  : boolean;
        is_ready : boolean;
    end record;

    procedure init_mproc (signal self_in : out microprogram_processor_in_record);
    procedure calculate (signal self_in : out microprogram_processor_in_record; start_address : in natural);
    function is_ready(self_out : microprogram_processor_out_record) return boolean;

    -- the address width of a ram of number_of_words words, a power of 2
    function address_width (number_of_words : positive) return natural;

    -- the instructions after a jump that run before it is taken : 3 with
    -- the program ram's output register, 2 without
    function jump_delay_slots (program_ram_output_register : boolean) return natural;

end package microprogram_interface_pkg;

------------------

package body microprogram_interface_pkg is

    procedure init_mproc (signal self_in : out microprogram_processor_in_record) is
    begin
        self_in.processor_requested <= false;
    end init_mproc;

    procedure calculate (signal self_in : out microprogram_processor_in_record; start_address : in natural) is
    begin
        self_in.processor_requested <= true;
        self_in.start_address <= start_address;
    end calculate;

    function is_ready(self_out : microprogram_processor_out_record) return boolean is
    begin
        return self_out.is_ready;
    end is_ready;

    function address_width (number_of_words : positive) return natural is
        variable retval : natural := 0;
    begin
        while 2**retval < number_of_words loop
            retval := retval + 1;
        end loop;
        return retval;
    end address_width;

    function jump_delay_slots (program_ram_output_register : boolean) return natural is
    begin
        return 2 + boolean'pos(program_ram_output_register);
    end jump_delay_slots;

end package body microprogram_interface_pkg;

--------------------------------------------
