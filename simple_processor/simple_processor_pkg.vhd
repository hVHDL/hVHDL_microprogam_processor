library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.processor_configuration_pkg.all;

package simple_processor_pkg is

    alias register_bit_width is work.processor_configuration_pkg.register_bit_width;

    type simple_processor_record is record
        processor_enabled    : boolean                 ;
        is_ready             : boolean                 ;
        program_counter      : natural range 0 to 1023 ;
        registers            : reg_array               ;
        instruction_pipeline : instruction_array       ;
        -- math unit for testing, will be removed later
    end record;

    function init_processor return simple_processor_record;
------------------------------------------------------------------------
    procedure create_simple_processor (
        signal self                    : inout simple_processor_record ;
        signal ram_read_instruction_in : out ram_read_in_record        ;
        ram_read_instruction_out       : in ram_read_out_record        ;
        signal ram_read_data_in        : out ram_read_in_record        ;
        ram_read_data_out              : in ram_read_out_record        ;
        signal ram_write_port          : out ram_write_in_record       ;
        used_instruction               : inout t_instruction);
------------------------------------------------------------------------     
    procedure request_processor (
        signal self : out simple_processor_record);
------------------------------------------------------------------------
    function program_is_ready ( self : simple_processor_record)
        return boolean;
------------------------------------------------------------------------
    function processor_is_enabled (
        self : simple_processor_record)
    return boolean;

end package simple_processor_pkg;

package body simple_processor_pkg is

------------------------------------------------------------------------     
    function init_processor return simple_processor_record
    is
        constant zero_all : simple_processor_record :=
        (
            processor_enabled    => false                       , -- boolean                 ;
            is_ready             => false                       , -- boolean                 ;
            program_counter      => 0                           , -- natural range 0 to 1023 ;
            registers            => (others => (others => '0')) , -- reg_array               ;
            instruction_pipeline => (others => (others => '0')) ); -- instruction_array       ;
    begin

        return zero_all;
        
    end init_processor;
------------------------------------------------------------------------     
    procedure create_simple_processor
    (
        signal self                    : inout simple_processor_record ;
        signal ram_read_instruction_in : out ram_read_in_record        ;
        ram_read_instruction_out       : in ram_read_out_record        ;
        signal ram_read_data_in        : out ram_read_in_record        ;
        ram_read_data_out              : in ram_read_out_record        ;
        signal ram_write_port          : out ram_write_in_record       ;
        used_instruction               : inout t_instruction
    ) is
    begin
        init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
    ------------------------------------------------------------------------
        self.is_ready <= false;
        used_instruction := write_instruction(nop);
        if self.processor_enabled then
            request_data_from_ram(ram_read_instruction_in, self.program_counter);

            if ram_read_is_ready(ram_read_instruction_out) then
                used_instruction := get_ram_data(ram_read_instruction_out);
            end if;

            if decode(used_instruction) = program_end then
                self.processor_enabled <= false;
                self.is_ready <= true;
            else
                self.program_counter <= self.program_counter + 1;
            end if;
        end if;
        self.instruction_pipeline <= used_instruction & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
    ------------------------------------------------------------------------
    end create_simple_processor;

    function program_is_ready
    (
        self : simple_processor_record
    )
    return boolean
    is
    begin
        return self.is_ready;
        
    end program_is_ready;

    procedure request_processor
    (
        signal self : out simple_processor_record
    ) is
    begin
        self.program_counter <= 0;
        self.processor_enabled <= true;
    end request_processor;

------------------------------------------------------------------------     
    function processor_is_enabled
    (
        self : simple_processor_record
    )
    return boolean
    is
    begin
        return self.processor_enabled;
    end processor_is_enabled;
------------------------------------------------------------------------     
end package body simple_processor_pkg;
