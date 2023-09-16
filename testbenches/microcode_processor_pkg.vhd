LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.real_to_fixed_pkg.all;
    use work.multiplier_pkg.radix_multiply;

package microcode_processor_pkg is


    type processor_with_ram_record is record
        ram_read_instruction_port : ram_read_port_record  ;
        ram_read_data_port        : ram_read_port_record  ;
        ram_write_port            : ram_write_port_record ;
        ram_write_port2           : ram_write_port_record ;
        write_address             : natural range 0 to 1023              ;
        read_address              : natural range 0 to 1023               ;
        register_address          : natural range 0 to 1023               ;
        program_counter           : natural range 0 to 1023;
        registers                 : reg_array;
    end record;

    function init_processor ( program_start_point : natural) return processor_with_ram_record;

    procedure create_processor_w_ram (
        signal self : inout processor_with_ram_record;
        ramsize : in natural);

    procedure create_processor (
        signal pgm_counter : inout natural;
        instruction : in std_logic_vector;
        signal reg  : inout reg_array);

    procedure create_processor (
        signal pgm_counter   : inout counter_array;
        ram_data             : in t_instruction;
        signal instruction_pipeline : inout instruction_array;
        signal reg           : inout reg_array);

end package microcode_processor_pkg;

package body microcode_processor_pkg is
------------------------------------------------------------------------
    function "+"
    (
        left, right : std_logic_vector 
    )
    return std_logic_vector 
    is
    begin
        return std_logic_vector(signed(left) + signed(right));
    end "+";
------------------------------------------------------------------------
    function "-"
    (
        left, right : std_logic_vector 
    )
    return std_logic_vector 
    is
    begin
        return std_logic_vector(signed(left) - signed(right));
    end "-";
------------------------------------------------------------------------
    function "*"
    (
        left, right : std_logic_vector 
    )
    return std_logic_vector 
    is
        
    begin
        return std_logic_vector(radix_multiply(signed(left), signed(right), 19));
    end "*";
------------------------------------------------------------------------
    function testi
    (
        instruction : std_logic_vector;
        reg : reg_array 
    )
    return reg_array
    is
        variable retval : reg_array := reg;

    begin

        CASE decode(instruction) is
            when add =>
                retval(get_dest(instruction)) := reg(get_arg1(instruction)) + reg(get_arg2(instruction));
            when sub =>
                retval(get_dest(instruction)) := reg(get_arg1(instruction)) - reg(get_arg2(instruction));
            when mpy =>
                retval(get_dest(instruction)) := reg(get_arg1(instruction)) * reg(get_arg2(instruction));
            when mpy_add =>
                retval(get_dest(instruction)) := reg(get_arg1(instruction)) * reg(get_arg2(instruction)) + reg(get_arg3(instruction));
            when div =>
            when jump        =>
            when ret         =>
            when program_end =>
            when ready       => --do nothing
            when nop         => --do nothing
        end CASE;

        return retval;
        
    end testi;
------------------------------------------------------------------------
    procedure create_processor
    (
        signal pgm_counter : inout natural;
        instruction        : in std_logic_vector;
        signal reg         : inout reg_array
    )
    is
    begin

        if decode(instruction) /= program_end then
            pgm_counter <= pgm_counter + 1;
        end if;

        reg <= testi(instruction, reg);
        
    end create_processor;
------------------------------------------------------------------------
    procedure create_processor
    (
        signal pgm_counter          : inout counter_array;
        ram_data                    : in t_instruction;
        signal instruction_pipeline : inout instruction_array;
        signal reg                  : inout reg_array
    )
    is
    begin

        if decode(instruction_pipeline(1)) /= program_end then
            pgm_counter(0)          <= pgm_counter(0) + 1;
            instruction_pipeline(0) <= ram_data;
            instruction_pipeline(1) <= instruction_pipeline(0);
        end if;
        pgm_counter(1) <= pgm_counter(0);

        reg <= testi(instruction_pipeline(1), reg);
        
    end create_processor;
------------------------------------------------------------------------
    function init_processor 
    ( 
        program_start_point : natural
    )
    return processor_with_ram_record
    is
        variable retval : processor_with_ram_record;
    begin
        retval := (
        init_ram_read_port  ,
        init_ram_read_port  ,
        init_ram_write_port ,
        init_ram_write_port ,
        63                  ,
        63                  ,
        0                   ,
        program_start_point,
        to_fixed((0.0, 0.10, 0.2, 0.3, 0.4, 0.5, 0.6, 0.1, 0.0), 19));
        
        return retval;
    end init_processor;
------------------------------------------------------------------------

    procedure create_processor_w_ram
    (
        signal self : inout processor_with_ram_record;
        ramsize : in natural
    ) is
        constant register_memory_start_address : integer := ramsize-self.registers'length;
        constant zero : std_logic_vector(self.registers(0)'range) := (others => '0');
    begin

        request_data_from_ram(self.ram_read_instruction_port, self.program_counter);
        create_processor(self.program_counter , get_ram_data(self.ram_read_instruction_port) , self.registers);
    --------------------------------------------------
        if self.read_address > register_memory_start_address then
            if self.read_address < ramsize then
                self.read_address <= self.read_address + 1;
                request_data_from_ram(self.ram_read_data_port, self.read_address);
            end if;
        end if;

        if ram_read_is_ready(self.ram_read_data_port) then
            self.registers <= self.registers(0 to self.registers'length-2) & get_ram_data(self.ram_read_data_port);
            self.register_address <= self.register_address + 1;
        end if;

        if self.write_address =  register_memory_start_address then
            self.read_address <= register_memory_start_address;
            self.register_address <= 0;
        end if;

    --------------------------------------------------
        -- save registers to ram
        if decode(get_ram_data(self.ram_read_instruction_port)) = ready then
            self.write_address <= register_memory_start_address;
        end if;

        if self.write_address < ramsize then
            self.write_address <= self.write_address + 1;
            write_data_to_ram(self.ram_write_port, self.write_address, self.registers(0));
            self.registers <= self.registers(0 to self.registers'length-2) & zero;
        end if;

    end create_processor_w_ram;

end package body microcode_processor_pkg;
