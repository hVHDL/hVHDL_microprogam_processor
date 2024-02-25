library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.processor_configuration_pkg.all;
    use work.float_to_real_conversions_pkg.all;
    use work.float_assembler_pkg.all;

package float_example_program_pkg is

    function build_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address : natural) return ram_array;
    function build_nmp_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address, temp_address : natural) return ram_array;

end package float_example_program_pkg;

package body float_example_program_pkg is

------------------------------------------------------------------------
    function build_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address : natural) return ram_array
    is

        ------------------------------
        constant u    : natural := 3;
        constant y    : natural := 2;
        constant g    : natural := 1;
        constant temp : natural := 0;

        ------------------------------
        constant load_parameters : program_array :=(
                write_instruction(load , u , u_address) ,
                write_instruction(load , y , y_address) ,
                write_instruction(load , g , g_address) ,
                write_instruction(nop));

        ------------------------------
        constant save_and_end : program_array :=(
            write_instruction(save , y , y_address) ,
            write_instruction(program_end));

        ------------------------------
        constant program : program_array :=(
            load_parameters              &
            sub(temp, u, y)              &
            multiply_add(y, temp, g, y)  &
            save_and_end);
        ------------------------------
        variable retval : ram_array := (others => (others => '0'));

    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        retval(y_address) := to_std_logic_vector(to_float(0.0));
        retval(u_address) := to_std_logic_vector(to_float(0.5));
        retval(g_address) := to_std_logic_vector(to_float(filter_gain));
            
        return retval;
        
    end build_sw;
------------------------------------------------------------------------
    function sequential_block
    (
        program : program_array
    )
    return program_array
    is
        variable retval : program_array(0 to number_of_pipeline_stages-1) := (others => write_instruction(nop));
    begin

        if program'length < retval'length then
            for i in program'range loop
                retval(i) := program(i);
            end loop;
            return retval;
        else
            return program;
        end if;
        
    end sequential_block;
------------------------------------------------------------------------
    function sequential_block
    (
        instruction : t_instruction
    )
    return program_array
    is
    begin
        return sequential_block(program_array'(0=>instruction));
    end sequential_block;
------------------------------------------------------------------------
    function build_nmp_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address, temp_address : natural) return ram_array
    is

        -- does the memory get read with new value?
        ------------------------------
        constant program : program_array :=(
            sequential_block(
                program_array'(write_instruction(sub, temp_address, u_address, y_address)    ,
                write_instruction(sub, temp_address+1, u_address, y_address+1) ,
                write_instruction(sub, temp_address+2, u_address, y_address+2) ,
                write_instruction(sub, temp_address+3, u_address, y_address+3) ,
                write_instruction(sub, temp_address+4, u_address, y_address+4) ,
                write_instruction(sub, temp_address+5, u_address, y_address+5) ,
                write_instruction(sub, temp_address+6, u_address, y_address+6) ,
                write_instruction(sub, temp_address+7, u_address, y_address+7))
            ) &
            sequential_block(
                program_array'(write_instruction(mpy_add, y_address, temp_address, g_address, y_address) ,
                write_instruction(mpy_add, y_address+1, temp_address+1, g_address+1, y_address+1) ,
                write_instruction(mpy_add, y_address+2, temp_address+2, g_address+2, y_address+2) ,
                write_instruction(mpy_add, y_address+3, temp_address+3, g_address+3, y_address+3) ,
                write_instruction(mpy_add, y_address+4, temp_address+4, g_address+4, y_address+4) ,
                write_instruction(mpy_add, y_address+5, temp_address+5, g_address+5, y_address+5) ,
                write_instruction(mpy_add, y_address+6, temp_address+6, g_address+6, y_address+6) ,
                write_instruction(mpy_add, y_address+7, temp_address+7, g_address+7, y_address+7))
            ) &
            write_instruction(program_end));
        ------------------------------
        variable retval : ram_array := (others => (others => '0'));

    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        retval(y_address) := to_std_logic_vector(to_float(0.0));
        retval(u_address) := to_std_logic_vector(to_float(0.5));
        retval(g_address) := to_std_logic_vector(to_float(filter_gain));
        for i in 0 to 7 loop
            retval(g_address+i) := to_std_logic_vector(to_float(filter_gain + filter_gain*(real(i))));
        end loop;
            
        return retval;
        
    end build_nmp_sw;
------------------------------------------------------------------------
end package body float_example_program_pkg;
