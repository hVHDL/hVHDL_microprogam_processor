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
            load_parameters           &
            sub(temp, u, y)           &
            multiply(temp , temp , g) &
            add(y, y, temp)           &
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

end package body float_example_program_pkg;
