package microinstruction_pkg is new work.generic_microinstruction_pkg 
    generic map(
            g_instruction_bit_width      => 32
            ,g_data_bit_width            => 32
            ,g_number_of_registers       => 5
            ,g_number_of_pipeline_stages => 8);
