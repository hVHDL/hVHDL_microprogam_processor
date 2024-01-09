library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.multiplier_pkg.radix_multiply;
    use work.processor_configuration_pkg.all;

package command_pipeline_pkg is

    type fixed_point_command_pipeline_record is record
        add_a          : std_logic_vector(19 downto 0) ;
        add_b          : std_logic_vector(19 downto 0) ;
        add_result     : std_logic_vector(19 downto 0) ;
        mpy_a          : std_logic_vector(19 downto 0) ;
        mpy_b          : std_logic_vector(19 downto 0) ;
        mpy_a1         : std_logic_vector(19 downto 0) ;
        mpy_b1         : std_logic_vector(19 downto 0) ;
        mpy_raw_result : signed(39 downto 0)           ;
        mpy_result     : std_logic_vector(19 downto 0) ;
    end record;

    function init_fixed_point_command_pipeline return fixed_point_command_pipeline_record;

    procedure create_command_pipeline (
        signal self                    : inout fixed_point_command_pipeline_record ;
        signal ram_read_instruction_in : out ram_read_in_record                    ;
        ram_read_instruction_out       : in ram_read_out_record                    ;
        signal ram_read_data_in        : out ram_read_in_record                    ;
        ram_read_data_out              : in ram_read_out_record                    ;
        signal ram_write_port          : out ram_write_in_record                   ;
        signal registers               : inout reg_array                           ;
        signal instruction_pipeline    : inout instruction_array                   ;
        instruction                    : in t_instruction);

end package command_pipeline_pkg;

package body command_pipeline_pkg is

    function init_fixed_point_command_pipeline return fixed_point_command_pipeline_record
    is
        constant init_values : fixed_point_command_pipeline_record := (
                add_a                => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                add_b                => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                add_result           => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                mpy_a                => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                mpy_b                => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                mpy_a1               => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                mpy_b1               => (others => '0'),             -- std_logic_vector(19 downto 0) ;
                mpy_raw_result       => (others => '0'),             -- signed(39 downto 0)           ;
                mpy_result           => (others => '0'));            -- std_logic_vector(19 downto 0) ;
    begin

        return init_values;
        
    end init_fixed_point_command_pipeline;

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

    procedure create_command_pipeline
    (
        signal self                    : inout fixed_point_command_pipeline_record ;
        signal ram_read_instruction_in : out ram_read_in_record                    ;
        ram_read_instruction_out       : in ram_read_out_record                    ;
        signal ram_read_data_in        : out ram_read_in_record                    ;
        ram_read_data_out              : in ram_read_out_record                    ;
        signal ram_write_port          : out ram_write_in_record                   ;
        signal registers               : inout reg_array                           ;
        signal instruction_pipeline    : inout instruction_array                   ;
        instruction                    : in t_instruction
    ) is
        variable used_instruction : t_instruction;
    begin
        used_instruction := instruction;
        --stage -1
        CASE decode(used_instruction) is
            WHEN load =>
                request_data_from_ram(ram_read_data_in, get_sigle_argument(used_instruction));
            WHEN others => -- do nothing
        end CASE;
    ------------------------------------------------------------------------
    ------------------------------------------------------------------------
        used_instruction := instruction_pipeline(0);
        --stage 0
        CASE decode(used_instruction) is
            WHEN add =>
                self.add_a <= registers(get_arg1(used_instruction));
                self.add_b <= registers(get_arg2(used_instruction));
            WHEN sub =>
                self.add_a <=  registers(get_arg1(used_instruction));
                self.add_b <= -registers(get_arg2(used_instruction));
            WHEN mpy =>
                self.mpy_a <= registers(get_arg1(used_instruction));
                self.mpy_b <= registers(get_arg2(used_instruction));

            WHEN others => -- do nothing
        end CASE;
    ------------------------------------------------------------------------
        --stage 1
        used_instruction := instruction_pipeline(1);
        self.add_result <= self.add_a + self.add_b;
        self.mpy_a1     <= self.mpy_a;
        self.mpy_b1     <= self.mpy_b;
    ------------------------------------------------------------------------
        --stage 2
        used_instruction := instruction_pipeline(2);
        self.mpy_raw_result <= signed(self.mpy_a1) * signed(self.mpy_b1);

        CASE decode(used_instruction) is
            WHEN load =>
                registers(get_dest(used_instruction)) <= get_ram_data(ram_read_data_out);
            WHEN add | sub =>
                registers(get_dest(used_instruction)) <= self.add_result;

            WHEN others => -- do nothing
        end CASE;
    ------------------------------------------------------------------------
        --stage 3
        used_instruction := instruction_pipeline(3);
        self.mpy_result <= std_logic_vector(self.mpy_raw_result(38 downto 38-19));

        CASE decode(used_instruction) is
            WHEN save =>
                write_data_to_ram(ram_write_port, get_sigle_argument(used_instruction), registers(get_dest(used_instruction)));

            WHEN others => -- do nothing
        end CASE;
    ------------------------------------------------------------------------
        --stage 4
        used_instruction := instruction_pipeline(4);
        CASE decode(used_instruction) is
            WHEN mpy =>
                registers(get_dest(used_instruction)) <= self.mpy_result;
            WHEN others => -- do nothing
        end CASE;
        --stage 5
        used_instruction := instruction_pipeline(5);
    ------------------------------------------------------------------------
        
    end create_command_pipeline;

end package body command_pipeline_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------

library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.multiplier_pkg.radix_multiply;
    use work.processor_configuration_pkg.all;
    use work.command_pipeline_pkg.all;

package simple_processor_pkg is


    type simple_processor_record is record
        processor_enabled    : boolean                 ;
        is_ready             : boolean                 ;
        program_counter      : natural range 0 to 1023 ;
        registers            : reg_array               ;
        instruction_pipeline : instruction_array       ;
        -- math unit for testing, will be removed later
        command_pipeline : fixed_point_command_pipeline_record;
    end record;

    function init_processor return simple_processor_record;
------------------------------------------------------------------------
    procedure create_simple_processor (
        signal self                    : inout simple_processor_record;
        signal ram_read_instruction_in : out ram_read_in_record    ;
        ram_read_instruction_out       : in ram_read_out_record    ;
        signal ram_read_data_in        : out ram_read_in_record    ;
        ram_read_data_out              : in ram_read_out_record    ;
        signal ram_write_port          : out ram_write_in_record);
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
            processor_enabled    => false ,                       -- boolean                 ;
            is_ready             => false ,                       -- boolean                 ;
            program_counter      => 0,                           -- natural range 0 to 1023 ;
            registers            => (others => (others => '0')), -- reg_array               ;
            instruction_pipeline => (others => (others => '0')), -- instruction_array       ;
            command_pipeline     => init_fixed_point_command_pipeline);
    begin

        return zero_all;
        
    end init_processor;
------------------------------------------------------------------------     
    procedure create_simple_processor
    (
        signal self                    : inout simple_processor_record;
        signal ram_read_instruction_in : out ram_read_in_record    ;
        ram_read_instruction_out       : in ram_read_out_record    ;
        signal ram_read_data_in        : out ram_read_in_record    ;
        ram_read_data_out              : in ram_read_out_record    ;
        signal ram_write_port          : out ram_write_in_record
    ) is
        variable used_instruction : t_instruction;
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
            create_command_pipeline(
                self.command_pipeline     ,
                ram_read_instruction_in   ,
                ram_read_instruction_out  ,
                ram_read_data_in          ,
                ram_read_data_out         ,
                ram_write_port            ,
                self.registers            ,
                self.instruction_pipeline ,
                used_instruction);
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
