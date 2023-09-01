LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.real_to_fixed_pkg.all;

package microcode_processor_pkg is


    type processor_with_ram_record is record
        ram_read_port      : ram_read_port_record  ;
        ram_read_data_port : ram_read_port_record  ;
        ram_write_port     : ram_write_port_record ;
        write_address      : natural               ;
        read_address       : natural               ;
        register_address   : natural               ;
        program_counter    : natural;
        registers : realarray;
    end record;

    function init_processor ( program_start_point : natural) return processor_with_ram_record;

    procedure create_processor_w_ram (
        signal self : inout processor_with_ram_record);

    procedure create_processor (
        signal pgm_counter : inout natural;
        instruction : in std_logic_vector;
        signal reg  : inout realarray);

    procedure create_processor (
        signal pgm_counter   : inout counter_array;
        ram_data             : in t_instruction;
        signal instruction_pipeline : inout instruction_array;
        signal reg           : inout realarray);

end package microcode_processor_pkg;

package body microcode_processor_pkg is
------------------------------------------------------------------------
    procedure create_processor
    (
        signal pgm_counter : inout natural;
        instruction        : in std_logic_vector;
        signal reg         : inout realarray
    )
    is
    begin

        if decode(instruction) /= program_end then
            pgm_counter <= pgm_counter + 1;
        end if;

        CASE decode(instruction) is
            when add =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) + reg(get_arg2(instruction));
            when sub =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) - reg(get_arg2(instruction));
            when mpy =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction));
            when mpy_add =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction)) + reg(get_arg3(instruction));
            when div =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) / reg(get_arg2(instruction));
            when jump        =>
            when ret         =>
            when program_end =>
            when ready       => --do nothing
            when nop         => --do nothing
        end CASE;
        
    end create_processor;
------------------------------------------------------------------------
    procedure create_processor
    (
        signal pgm_counter          : inout counter_array;
        ram_data                    : in t_instruction;
        signal instruction_pipeline : inout instruction_array;
        signal reg                  : inout realarray
    )
    is
        variable instruction : t_instruction;
    begin

        instruction := instruction_pipeline(0);


        if decode(instruction) /= program_end then
            pgm_counter(0)          <= pgm_counter(0) + 1;
            instruction_pipeline(0) <= ram_data;
            instruction_pipeline(1) <= instruction_pipeline(0);
        end if;
        pgm_counter(1) <= pgm_counter(0);

        CASE decode(instruction) is
            when add =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) + reg(get_arg2(instruction));
            when sub =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) - reg(get_arg2(instruction));
            when mpy =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction));
            when mpy_add =>
                reg(get_dest(instruction)) <= reg(get_arg1(instruction)) * reg(get_arg2(instruction)) + reg(get_arg3(instruction));
            when div         => -- reg(get_dest(instruction)) <= reg(get_arg1(instruction)) / reg(get_arg2(instruction));
            when jump        =>
            when ret         =>
            when program_end =>
            when ready       => --do nothing
            when nop         => --do nothing
        end CASE;
        
    end create_processor;
------------------------------------------------------------------------

    function init_processor ( program_start_point : natural)
    return processor_with_ram_record
    is
        variable retval : processor_with_ram_record;
    begin
        retval := (
        init_ram_read_port  ,
        init_ram_read_port  ,
        init_ram_write_port ,
        40                  ,
        40                  ,
        0                   ,
        program_start_point,
        (0.0, 0.10, 0.2, 0.3, 0.4, 0.5, 0.6, 0.1, 0.0));
        
        return retval;
    end init_processor;
------------------------------------------------------------------------

    procedure create_processor_w_ram
    (
        signal self : inout processor_with_ram_record
    ) is
    begin
        create_ram_read_port(self.ram_read_port);
        create_ram_read_port(self.ram_read_data_port);
        create_ram_write_port(self.ram_write_port);
        request_data_from_ram(self.ram_read_port, self.program_counter);
        create_processor(self.program_counter , get_ram_data(self.ram_read_port) , self.registers);
    --------------------------------------------------
        if self.write_address < 40 then
            self.write_address <= self.write_address + 1;
            write_data_to_ram(self.ram_write_port, self.write_address, to_fixed(self.registers(self.write_address-(40-self.registers'length)), 19));
        end if;

        if self.read_address > 30 then
            if self.read_address < 40 then
                self.read_address <= self.read_address + 1;
                request_data_from_ram(self.ram_read_data_port, self.read_address);
            end if;
        end if;

        if ram_read_is_ready(self.ram_read_data_port) then
            self.registers(self.register_address) <= to_real(get_ram_data(self.ram_read_data_port), 19);
            self.register_address <= self.register_address + 1;
        end if;

        ------------------------------------------------------------------------
            
    end create_processor_w_ram;

end package body microcode_processor_pkg;
