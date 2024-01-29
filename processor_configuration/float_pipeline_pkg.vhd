library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.simple_processor_pkg.all;
    use work.processor_configuration_pkg.all;
    use work.float_alu_pkg.all;
    use work.float_type_definitions_pkg.all;
    use work.float_to_real_conversions_pkg.all;
    use work.float_assembler_pkg.all;

package float_pipeline_pkg is

    procedure create_float_command_pipeline (
        signal self                    : inout simple_processor_record ;
        signal float_alu                     : inout float_alu_record        ;
        signal ram_read_instruction_in : out ram_read_in_record        ;
        ram_read_instruction_out       : in ram_read_out_record        ;
        signal ram_read_data_in        : out ram_read_in_record        ;
        ram_read_data_out              : in ram_read_out_record        ;
        signal ram_write_port          : out ram_write_in_record       ;
        variable used_instruction      : inout t_instruction);

    function build_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address : natural) return ram_array;

end package float_pipeline_pkg;

package body float_pipeline_pkg is

        procedure create_float_command_pipeline
        (
            signal self                    : inout simple_processor_record ;
            signal float_alu                     : inout float_alu_record        ;
            signal ram_read_instruction_in : out ram_read_in_record        ;
            ram_read_instruction_out       : in ram_read_out_record        ;
            signal ram_read_data_in        : out ram_read_in_record        ;
            ram_read_data_out              : in ram_read_out_record        ;
            signal ram_write_port          : out ram_write_in_record       ;
            variable used_instruction      : inout t_instruction
        )
        is
            use work.normalizer_pkg.number_of_normalizer_pipeline_stages;
            use work.denormalizer_pkg.number_of_denormalizer_pipeline_stages;
        begin
        ------------------------------------------------------------------------
            --stage -1
            CASE decode(used_instruction) is
                WHEN load =>
                    request_data_from_ram(ram_read_data_in, get_sigle_argument(used_instruction));
                WHEN others => -- do nothing
            end CASE;

        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            CASE decode(used_instruction) is
                WHEN add => 
                    add(float_alu, 
                        to_float(self.registers(get_arg1(used_instruction))), 
                        to_float(self.registers(get_arg2(used_instruction))));

                WHEN sub =>
                    subtract(float_alu, 
                        to_float(self.registers(get_arg1(used_instruction))), 
                        to_float(self.registers(get_arg2(used_instruction))));
                WHEN mpy =>
                    multiply(float_alu, 
                        to_float(self.registers(get_arg1(used_instruction))), 
                        to_float(self.registers(get_arg2(used_instruction))));
                WHEN others => -- do nothing
            end CASE;
        ----------------------
            used_instruction := self.instruction_pipeline(3 + number_of_normalizer_pipeline_stages);
            CASE decode(used_instruction) is
                WHEN mpy =>
                    self.registers(get_dest(used_instruction)) <= to_std_logic_vector(get_multiplier_result(float_alu));
                WHEN others => -- do nothing
            end CASE;
        ----------------------
            used_instruction := self.instruction_pipeline(2 + number_of_normalizer_pipeline_stages + number_of_denormalizer_pipeline_stages);
            CASE decode(used_instruction) is
                WHEN add | sub => 
                    self.registers(get_dest(used_instruction)) <= to_std_logic_vector(get_add_result(float_alu));
                WHEN save =>
                    write_data_to_ram(ram_write_port, get_sigle_argument(used_instruction), self.registers(get_dest(used_instruction)));
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            used_instruction := self.instruction_pipeline(0);
            --stage 0
            CASE decode(used_instruction) is

                WHEN others => -- do nothing
            end CASE;
            --stage 1
            used_instruction := self.instruction_pipeline(1);
        ------------------------------------------------------------------------
            --stage 2
            used_instruction := self.instruction_pipeline(2);

            CASE decode(used_instruction) is
                WHEN load =>
                    self.registers(get_dest(used_instruction)) <= get_ram_data(ram_read_data_out);
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            used_instruction := self.instruction_pipeline(5);
            CASE decode(used_instruction) is
                WHEN others => -- do nothing
            end CASE;
            
        end create_float_command_pipeline;

------------------------------------------------------------------------
    function build_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address : natural) return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));

        constant u    : natural := 4;
        constant y    : natural := 2;
        constant g    : natural := 3;
        constant temp : natural := 1;

        constant load_parameters : program_array :=(
                write_instruction(load , u , u_address) ,
                write_instruction(load , y , y_address) ,
                write_instruction(load , g , g_address) ,
                write_instruction(nop));

        constant save_and_end : program_array :=(
            write_instruction(save , y , y_address) ,
            write_instruction(program_end));

        constant program : program_array :=(
            load_parameters                         &
            sub(temp, u, y)                         &
            multiply(temp , temp , g)               &
            add(y, y, temp)                         &
            save_and_end
        );
        ------------------------------

    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        retval(y_address) := to_std_logic_vector(to_float(0.0));
        retval(u_address) := to_std_logic_vector(to_float(0.5));
        retval(g_address) := to_std_logic_vector(to_float(filter_gain));
            
        return retval;
        
    end build_sw;

end package body float_pipeline_pkg;
