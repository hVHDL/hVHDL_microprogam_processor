
library ieee;
    use ieee.std_logic_1164.all;

package microprogram_processor_pkg is

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

end package microprogram_processor_pkg;

------------------

package body microprogram_processor_pkg is

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

end package body microprogram_processor_pkg;

--------------------------------------------
