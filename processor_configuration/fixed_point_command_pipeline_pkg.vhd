library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.multiplier_pkg.radix_multiply;
    use work.processor_configuration_pkg.all;

package command_pipeline_pkg is

    type command_pipeline_record is record
        add_a          : std_logic_vector(register_bit_width-1 downto 0) ;
        add_b          : std_logic_vector(register_bit_width-1 downto 0) ;
        add_result     : std_logic_vector(register_bit_width-1 downto 0) ;
        mpy_a          : std_logic_vector(register_bit_width-1 downto 0) ;
        mpy_b          : std_logic_vector(register_bit_width-1 downto 0) ;
        mpy_a1         : std_logic_vector(register_bit_width-1 downto 0) ;
        mpy_b1         : std_logic_vector(register_bit_width-1 downto 0) ;
        mpy_raw_result : signed(register_bit_width*2-1 downto 0)           ;
        mpy_result     : std_logic_vector(register_bit_width-1 downto 0) ;
    end record;

    function init_fixed_point_command_pipeline return command_pipeline_record;

    procedure create_command_pipeline (
        signal self                    : inout command_pipeline_record ;
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

    function init_fixed_point_command_pipeline return command_pipeline_record
    is
        constant init_values : command_pipeline_record := (
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

    procedure create_command_pipeline
    (
        signal self                    : inout command_pipeline_record ;
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
        self.mpy_result <= std_logic_vector(self.mpy_raw_result(register_bit_width*2-2 downto register_bit_width*2-1-register_bit_width));

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

