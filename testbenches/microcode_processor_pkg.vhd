LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.microinstruction_pkg.all;
    use work.test_programs_pkg.all;
    use work.multiplier_pkg.radix_multiply;
    use work.multi_port_ram_pkg.all;

package microcode_processor_pkg is


    type processor_with_ram_record is record
        processor_enabled : boolean;
        read_address           : natural range 0 to 1023 ;
        write_address          : natural range 0 to 1023 ;
        register_write_counter : natural range 0 to 1023 ;
        register_read_counter  : natural range 0 to 15 ;
        register_load_counter  : natural range 0 to 15 ;
        program_counter        : natural range 0 to 1023 ;
        registers              : reg_array               ;
        instruction_pipeline   : instruction_array;
        processor_has_stalled  : boolean;
        stall_counter          : natural range 0 to 31;
        -- math unit for testing, will be removed later
        add_a          : std_logic_vector(19 downto 0);
        add_b          : std_logic_vector(19 downto 0);
        add_result     : std_logic_vector(19 downto 0);
        mpy_a          : std_logic_vector(19 downto 0);
        mpy_b          : std_logic_vector(19 downto 0);
        mpy_a1          : std_logic_vector(19 downto 0);
        mpy_b1          : std_logic_vector(19 downto 0);
        mpy_raw_result : signed(39 downto 0);
        mpy_result     : std_logic_vector(19 downto 0);
    end record;

    function init_processor ( program_start_point : natural) return processor_with_ram_record;

    procedure create_processor_w_ram (
        signal self                    : inout processor_with_ram_record;
        signal ram_read_instruction_in : out ram_read_in_record    ;
        ram_read_instruction_out       : in ram_read_out_record    ;
        signal ram_read_data_in        : out ram_read_in_record    ;
        ram_read_data_out              : in ram_read_out_record    ;
        signal ram_write_port          : out ram_write_in_record   ;
        ramsize                        : in natural);

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

    function register_load_ready ( self : processor_with_ram_record)
        return boolean;

    function register_write_ready ( self : processor_with_ram_record)
        return boolean;

    function program_is_ready ( self : processor_with_ram_record)
        return boolean;

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
            processor_enabled      => true,
            read_address           => 35                  ,
            write_address          => 35                  ,
            register_write_counter => reg_array'length    ,
            register_read_counter  => reg_array'length    ,
            register_load_counter  => reg_array'length    ,
            program_counter        => program_start_point ,

            registers            => (others => (others => '0')) ,
            instruction_pipeline => (others => (others => '0')) ,

            processor_has_stalled  => false ,
            stall_counter => 0,
            -- math unit                
            add_a           => (others => '0') ,
            add_b           => (others => '0') ,
            add_result      => (others => '0') ,

            mpy_a          => (others => '0') ,
            mpy_b          => (others => '0') ,
            mpy_a1         => (others => '0') ,
            mpy_b1         => (others => '0') ,
            mpy_raw_result => (others => '0') ,
            mpy_result     => (others => '0')
        );
        return retval;
    end init_processor;
------------------------------------------------------------------------
    procedure create_processor_w_ram
    (
        signal self                    : inout processor_with_ram_record;
        signal ram_read_instruction_in : out ram_read_in_record    ;
        ram_read_instruction_out       : in ram_read_out_record    ;
        signal ram_read_data_in        : out ram_read_in_record    ;
        ram_read_data_out              : in ram_read_out_record    ;
        signal ram_write_port          : out ram_write_in_record   ;
        ramsize                        : in natural
    ) is
        variable active_instruction          : std_logic_vector(19 downto 0);
        constant register_memory_start_address : integer := ramsize-self.registers'length;
        constant zero                          : std_logic_vector(self.registers(0)'range) := (others => '0');
        variable used_instruction              : std_logic_vector(self.instruction_pipeline(0)'range);
    begin
        init_ram(ram_read_instruction_in, ram_read_data_in, ram_write_port);
    --------------------------------------------------
        -- save registers to ram
        if self.register_read_counter < self.registers'length then
            self.register_read_counter <= self.register_read_counter + 1;
            self.read_address          <= self.read_address + 1;
            request_data_from_ram(ram_read_data_in, self.read_address);
        end if;

        if ram_read_is_ready(ram_read_data_out) then
            self.register_load_counter <= self.register_load_counter + 1;
            self.registers(self.register_load_counter) <= get_ram_data(ram_read_data_out);
        end if;

        if self.register_write_counter < self.registers'length then
            self.write_address          <= self.write_address + 1;
            self.register_write_counter <= self.register_write_counter + 1;
            write_data_to_ram(ram_write_port, self.write_address, self.registers(self.register_write_counter));
        end if;
    ------------------------------------------------------------------------
    ------------------------------------------------------------------------
        if self.processor_enabled then
            request_data_from_ram(ram_read_instruction_in, self.program_counter);
        end if;

        active_instruction := write_instruction(nop);
        if ram_read_is_ready(ram_read_instruction_out) then
            active_instruction := get_ram_data(ram_read_instruction_out);
            if decode(active_instruction) /= program_end then
                self.program_counter <= self.program_counter + 1;
            end if;
        end if;

        if (decode(active_instruction) = save_registers) then
            if self.processor_has_stalled = false then
                self.processor_has_stalled <= true;
                self.stall_counter <= 10;
            end if;
        end if;

        if self.stall_counter > 0 then
            self.stall_counter   <= self.stall_counter - 1;
            self.program_counter <= self.program_counter;
            active_instruction := write_instruction(program_end);
        end if;

        if self.stall_counter = 1 then
            self.processor_has_stalled <= false;
        end if;
        
        self.instruction_pipeline <= active_instruction & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
        if decode(active_instruction) = program_end then
            self.instruction_pipeline <= write_instruction(program_end) & self.instruction_pipeline(0 to self.instruction_pipeline'high-1);
        end if;

    ------------------------------------------------------------------------
        --stage 0
        used_instruction := self.instruction_pipeline(0);
    ------------------------------------------------------------------------
        --stage 1
        used_instruction := self.instruction_pipeline(1);

        CASE decode(used_instruction) is
            WHEN add =>
                self.add_a <= self.registers(get_arg1(used_instruction));
                self.add_b <= self.registers(get_arg2(used_instruction));
            WHEN sub =>
                self.add_a <=  self.registers(get_arg1(used_instruction));
                self.add_b <= -self.registers(get_arg2(used_instruction));
            WHEN mpy =>
                self.mpy_a <= self.registers(get_arg1(used_instruction));
                self.mpy_b <= self.registers(get_arg2(used_instruction));
            WHEN others => -- do nothing
        end CASE;
    ------------------------------------------------------------------------
        --stage 2
        used_instruction := self.instruction_pipeline(2);

        self.add_result <= self.add_a + self.add_b;
        self.mpy_a1     <= self.mpy_a;
        self.mpy_b1     <= self.mpy_b;

    ------------------------------------------------------------------------
        --stage 3
        used_instruction := self.instruction_pipeline(3);
        
        self.mpy_raw_result <= signed(self.mpy_a1) * signed(self.mpy_b1);
        
        CASE decode(used_instruction) is
            WHEN add | sub =>
                self.registers(get_dest(used_instruction)) <= self.add_result;
            WHEN others => -- do nothing
        end CASE;

    ------------------------------------------------------------------------
        --stage 4
        used_instruction := self.instruction_pipeline(4);
        self.mpy_result <= std_logic_vector(self.mpy_raw_result(38 downto 38-19));


    ------------------------------------------------------------------------
        --stage 5
        used_instruction := self.instruction_pipeline(5);
        CASE decode(used_instruction) is
            WHEN mpy =>
                self.registers(get_dest(used_instruction)) <= self.mpy_result;
            WHEN others => -- do nothing
        end CASE;

    ------------------------------------------------------------------------
        --stage 6

    ------------------------------------------------------------------------
    end create_processor_w_ram;
------------------------------------------------------------------------
    function register_load_ready
    (
        self : processor_with_ram_record
    )
    return boolean
    is
    begin
        return self.register_load_counter = self.registers'length-1;
        
    end register_load_ready;
------------------------------------------------------------------------
    function register_write_ready
    (
        self : processor_with_ram_record
    )
    return boolean
    is
    begin

        return self.register_write_counter = self.registers'length-1;
       
    end register_write_ready;
------------------------------------------------------------------------
    function program_is_ready
    (
        self : processor_with_ram_record
    )
    return boolean
    is
    begin
        return decode(self.instruction_pipeline(4)) = ready;
        
    end program_is_ready;
------------------------------------------------------------------------
end package body microcode_processor_pkg;
