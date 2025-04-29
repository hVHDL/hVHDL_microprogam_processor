
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package microprogram_processor_pkg is

    type microprogram_processor_in_record is record
        processor_requested  : boolean;
        start_address        : natural;
    end record;

    type microprogram_processor_out_record is record
        is_busy : boolean;
    end record;

    procedure init_mproc (signal self_in : out microprogram_processor_in_record);

end package microprogram_processor_pkg;

package body microprogram_processor_pkg is

    procedure init_mproc (signal self_in : out microprogram_processor_in_record) is
    begin
        self_in.processor_requested <= false;
    end init_mproc;

end package body microprogram_processor_pkg;
