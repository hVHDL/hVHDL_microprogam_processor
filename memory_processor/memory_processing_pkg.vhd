LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.simple_processor_pkg.all;
    use work.processor_configuration_pkg.all;
    use work.float_alu_pkg.all;
    use work.float_type_definitions_pkg.all;
    use work.float_to_real_conversions_pkg.all;
    use work.float_example_program_pkg.all;

package memory_processing_pkg is

    procedure create_memory_process_pipeline (
        signal self                     : inout simple_processor_record ;
        signal float_alu                : inout float_alu_record        ;
        variable used_instruction       : inout t_instruction           ;
        signal ram_read_instruction_out : in ram_read_out_record        ;
        signal ram_read_data_in         : out ram_read_in_record        ;
        signal ram_read_data_out        : in ram_read_out_record        ;
        signal ram_read_2_data_in       : out ram_read_in_record        ;
        signal ram_read_2_data_out      : in ram_read_out_record        ;
        signal ram_read_3_data_in       : out ram_read_in_record        ;
        signal ram_read_3_data_out      : in ram_read_out_record        ;
        signal ram_write_port           : out ram_write_in_record);

end package memory_processing_pkg;

package body memory_processing_pkg is


    procedure create_memory_process_pipeline
    (
        signal self                     : inout simple_processor_record ;
        signal float_alu                : inout float_alu_record        ;
        variable used_instruction       : inout t_instruction           ;
        signal ram_read_instruction_out : in ram_read_out_record        ;
        signal ram_read_data_in         : out ram_read_in_record        ;
        signal ram_read_data_out        : in ram_read_out_record        ;
        signal ram_read_2_data_in       : out ram_read_in_record        ;
        signal ram_read_2_data_out      : in ram_read_out_record        ;
        signal ram_read_3_data_in       : out ram_read_in_record        ;
        signal ram_read_3_data_out      : in ram_read_out_record        ;
        signal ram_write_port           : out ram_write_in_record
        
    ) is
    begin
        --stage -1
        CASE decode(used_instruction) is
            WHEN load =>
                request_data_from_ram(ram_read_data_in , get_sigle_argument(used_instruction));
            WHEN add => 
                request_data_from_ram(ram_read_data_in   , get_arg1(used_instruction));
                request_data_from_ram(ram_read_2_data_in , get_arg2(used_instruction));
            WHEN sub =>
                request_data_from_ram(ram_read_data_in   , get_arg1(used_instruction));
                request_data_from_ram(ram_read_2_data_in , get_arg2(used_instruction));
            WHEN mpy =>
                request_data_from_ram(ram_read_data_in   , get_arg1(used_instruction));
                request_data_from_ram(ram_read_2_data_in , get_arg2(used_instruction));
            WHEN mpy_add =>
                request_data_from_ram(ram_read_data_in   , get_arg1(used_instruction));
                request_data_from_ram(ram_read_2_data_in , get_arg2(used_instruction));
                request_data_from_ram(ram_read_3_data_in , get_arg3(used_instruction));
            WHEN others => -- do nothing
        end CASE;
    ------------------------------------------------------------------------
        --stage 2
        used_instruction := self.instruction_pipeline(2);

        CASE decode(used_instruction) is
            WHEN load =>
                self.registers(get_dest(used_instruction)) <= get_ram_data(ram_read_data_out);

            WHEN add => 
                madd(float_alu                                ,
                    to_float(1.0)                             ,
                    to_float(get_ram_data(ram_read_data_out)) ,
                    to_float(get_ram_data(ram_read_2_data_out)));
            WHEN sub =>
                madd(float_alu                                  ,
                    to_float(-1.0)                              ,
                    to_float(get_ram_data(ram_read_2_data_out)) ,
                    to_float(get_ram_data(ram_read_data_out)));
            WHEN mpy =>
                madd(float_alu                                  ,
                    to_float(get_ram_data(ram_read_data_out))   ,
                    to_float(get_ram_data(ram_read_2_data_out)) ,
                    to_float(0.0));
            WHEN mpy_add =>
                madd(float_alu                                  ,
                    to_float(get_ram_data(ram_read_data_out))   ,
                    to_float(get_ram_data(ram_read_2_data_out)) ,
                    to_float(get_ram_data(ram_read_3_data_out)));
            WHEN others => -- do nothing
        end CASE;
    ----------------------
        used_instruction := self.instruction_pipeline(3 + alu_timing.madd_pipeline_depth-1);
        CASE decode(used_instruction) is
            WHEN add | sub | mpy | mpy_add => 
                write_data_to_ram(ram_write_port, get_dest(used_instruction), to_std_logic_vector(get_add_result(float_alu)));
            WHEN others => -- do nothing
        end CASE;
        
    end create_memory_process_pipeline;

end package body memory_processing_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------
