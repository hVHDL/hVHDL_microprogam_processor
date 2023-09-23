LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.ram_read_pkg.all;
    use work.ram_write_pkg.all;
    use work.multiplier_pkg.radix_multiply;

package microcode_processor_pkg is


    type processor_with_ram_record is record
        ram_read_instruction_port : ram_read_port_record    ;
        ram_read_data_port        : ram_read_port_record    ;
        ram_write_port            : ram_write_port_record   ;
        ram_write_port2           : ram_write_port_record   ;
        read_address              : natural range 0 to 1023 ;
        write_address             : natural range 0 to 1023 ;
        register_write_counter    : natural range 0 to 1023 ;
        register_read_counter     : natural range 0 to 15 ;
        register_load_counter     : natural range 0 to 15 ;
        program_counter           : natural range 0 to 1023 ;
        registers                 : reg_array               ;
        instruction_pipeline      : instruction_array;
        -- math unit for testing, will be removed later
        add_a                     : std_logic_vector(19 downto 0);
        add_b                     : std_logic_vector(19 downto 0);
        add_result                : std_logic_vector(19 downto 0);

        mpy_a                     : std_logic_vector(19 downto 0);
        mpy_b                     : std_logic_vector(19 downto 0);
        mpy_raw_result            : signed(39 downto 0);
        mpy_result                : std_logic_vector(19 downto 0);
    end record;

    function init_processor ( program_start_point : natural) return processor_with_ram_record;

    procedure create_processor_w_ram (
        signal self : inout processor_with_ram_record;
        ramsize : in natural);

    function init_ram(program : program_array) return ram_array;

    procedure save_old_and_load_new_registers (
        signal self : inout processor_with_ram_record;
        read_offset : in natural;
        write_offset : in natural);

    procedure load_registers (
        signal self : inout processor_with_ram_record;
        read_offset : in natural);

    procedure save_registers (
        signal self : inout processor_with_ram_record;
        write_offset : in natural);

    function write_register_values_to_ram (
        ram_to_be_intialized : ram_array;
        register_init_values : reg_array;
        end_address : natural)
    return ram_array;

end package microcode_processor_pkg;

package body microcode_processor_pkg is
------------------------------------------------------------------------
    function init_ram(program : program_array) return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));
    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        return retval;
    end init_ram;
------------------------------------------------------------------------
    function write_register_values_to_ram
    (
        ram_to_be_intialized : ram_array;
        register_init_values : reg_array;
        end_address : natural
    )
    return ram_array
    is
        variable retval : ram_array := ram_to_be_intialized;
    begin

        for i in end_address-reg_array'high to end_address loop
            retval(i) := register_init_values(i-(end_address-reg_array'high));
        end loop;

        return retval;
        
    end write_register_values_to_ram;
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

    function "-"
    (
        left : std_logic_vector 
    )
    return std_logic_vector 
    is
    begin
        return std_logic_vector(-signed(left));
    end "-";
------------------------------------------------------------------------
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
    procedure load_registers
    (
        signal self : inout processor_with_ram_record;
        read_offset : in natural
    ) is
    begin
        self.register_read_counter <= 0;
        self.register_load_counter <= 0;
        self.read_address           <= read_offset-self.registers'high;
    end load_registers;
------------------------------------------------------------------------
    procedure save_registers
    (
        signal self : inout processor_with_ram_record;
        write_offset : in natural
    ) is
    begin
        self.register_write_counter <= 0;
        self.write_address          <= write_offset-self.registers'high;
        
    end save_registers;
------------------------------------------------------------------------
    procedure save_old_and_load_new_registers
    (
        signal self : inout processor_with_ram_record;
        read_offset : in natural;
        write_offset : in natural
    )
    is

    begin
        load_registers(self, read_offset);
        save_registers(self, write_offset);
    end save_old_and_load_new_registers;
------------------------------------------------------------------------
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
            ram_read_instruction_port => init_ram_read_port          ,
            ram_read_data_port        => init_ram_read_port          ,
            ram_write_port            => init_ram_write_port         ,
            ram_write_port2           => init_ram_write_port         ,
            read_address              => 35                          ,
            write_address             => 35                          ,
            register_write_counter    => reg_array'length            ,
            register_read_counter     => reg_array'length            ,
            register_load_counter     => reg_array'length            ,
            program_counter           => program_start_point         ,
            registers                 => (others => (others => '0')),

            instruction_pipeline      => (others => (others => '0')) ,
            -- math unit                
            add_a                     => (others => '0'),
            add_b                     => (others => '0'),
            add_result                => (others => '0'),

            mpy_a                     => (others => '0'),
            mpy_b                     => (others => '0'),
            mpy_raw_result            => (others => '0')  ,
            mpy_result                => (others => '0')
        );
        return retval;
    end init_processor;
------------------------------------------------------------------------
    procedure create_processor_w_ram
    (
        signal self : inout processor_with_ram_record;
        ramsize : in natural
    ) is
        variable ram_data : std_logic_vector(19 downto 0);
        constant register_memory_start_address : integer := ramsize-self.registers'length;
        constant zero : std_logic_vector(self.registers(0)'range) := (others => '0');
    begin
    --------------------------------------------------
        -- save registers to ram
        if decode(self.instruction_pipeline(2)) = ready then
            save_registers(self, register_memory_start_address);
        end if;

        if self.register_read_counter < self.registers'length then
            self.register_read_counter <= self.register_read_counter + 1;
            self.read_address          <= self.read_address + 1;
            request_data_from_ram(self.ram_read_data_port, self.read_address);
        end if;

        if ram_read_is_ready(self.ram_read_data_port) then
            self.register_load_counter <= self.register_load_counter + 1;
            self.registers(self.register_load_counter) <= get_ram_data(self.ram_read_data_port);
        end if;

        if self.register_write_counter < self.registers'length then
            self.write_address          <= self.write_address + 1;
            self.register_write_counter <= self.register_write_counter + 1;
            write_data_to_ram(self.ram_write_port, self.write_address, self.registers(self.register_write_counter));
        end if;
    ------------------------------------------------------------------------
    ------------------------------------------------------------------------
        request_data_from_ram(self.ram_read_instruction_port, self.program_counter);

        ram_data := get_ram_data(self.ram_read_instruction_port);

        self.instruction_pipeline <= ram_data & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
        if decode(ram_data) /= program_end then
            self.program_counter <= self.program_counter + 1;
        end if;

        --stage 0
        CASE decode(self.instruction_pipeline(0)) is
            WHEN add =>
                self.add_a <= self.registers(get_arg1(self.instruction_pipeline(0)));
                self.add_b <= self.registers(get_arg2(self.instruction_pipeline(0)));
            WHEN sub =>
                self.add_a <=  self.registers(get_arg1(self.instruction_pipeline(0)));
                self.add_b <= -self.registers(get_arg2(self.instruction_pipeline(0)));
            WHEN mpy =>
                self.mpy_a <= self.registers(get_arg1(self.instruction_pipeline(0)));
                self.mpy_b <= self.registers(get_arg2(self.instruction_pipeline(0)));
            WHEN others => -- do nothing
        end CASE;

        --stage 1
        self.add_result     <= self.add_a + self.add_b;
        self.mpy_raw_result <= signed(self.mpy_a) * signed(self.mpy_b);

        --stage 2
        self.mpy_result <= std_logic_vector(self.mpy_raw_result(38 downto 38-19));
        
        CASE decode(self.instruction_pipeline(2)) is
            WHEN add | sub =>
                self.registers(get_dest(self.instruction_pipeline(2))) <= self.add_result;
            WHEN others => -- do nothing
        end CASE;

        --stage 3
        CASE decode(self.instruction_pipeline(3)) is
            WHEN mpy =>
                self.registers(get_dest(self.instruction_pipeline(3))) <= self.mpy_result;
            WHEN others => -- do nothing
        end CASE;

        --stage 4

        --stage 5
    end create_processor_w_ram;
------------------------------------------------------------------------
end package body microcode_processor_pkg;
