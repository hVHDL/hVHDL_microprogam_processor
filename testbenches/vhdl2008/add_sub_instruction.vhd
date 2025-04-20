LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

entity instruction is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
        ;package mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
       );
    port(
        clock : in std_logic
        ;ram_read_in  : out mp_ram_pkg.ram_read_in_array
        ;ram_read_out : in mp_ram_pkg.ram_read_out_array
        ;ram_write_in : out mp_ram_pkg.ram_write_in_record
        ;instr_pipeline : in microinstruction_pkg.instruction_pipeline_array
    );
    use microinstruction_pkg.all;
    use mp_ram_pkg.all;
    use work.real_to_fixed_pkg.all;
end;

architecture add_sub_mpy of instruction is

    signal a, b, c: signed(31 downto 0);
    signal mpy_res : signed(63 downto 0);

begin

    mpy_add_sub : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(ram_read_in);
            init_mp_write(ram_write_in);

            ---------------
            if ram_read_is_ready(ram_read_out(4)) then
                CASE decode(get_ram_data(ram_read_out(4))) is
                    WHEN add =>
                        request_data_from_ram(ram_read_in(2)
                        , get_arg1(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(ram_read_in(1)
                        , get_arg2(get_ram_data(ram_read_out(4))));

                    WHEN sub =>
                        request_data_from_ram(ram_read_in(2)
                        , get_arg1(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(ram_read_in(1)
                        , get_arg2(get_ram_data(ram_read_out(4))));

                    WHEN mpy_add =>
                        request_data_from_ram(ram_read_in(0)
                        , get_arg1(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(ram_read_in(1)
                        , get_arg2(get_ram_data(ram_read_out(4))));

                        request_data_from_ram(ram_read_in(2)
                        , get_arg3(get_ram_data(ram_read_out(4))));

                    WHEN others => -- do nothing
                end CASE;
            end if;
            ---------------
            mpy_res <= a * b + resize(shift_left(c , 14) , 63);

            CASE decode(instr_pipeline(2)) is
                WHEN add =>
                    a <= to_fixed(1.0, 32, 14);
                    b <= signed(get_ram_data(ram_read_out(1)));
                    c <= signed(get_ram_data(ram_read_out(2)));

                WHEN sub =>
                    a <= to_fixed(1.0, 32, 14);
                    b <=  signed(get_ram_data(ram_read_out(1)));
                    c <= -signed(get_ram_data(ram_read_out(2)));

                WHEN mpy_add =>
                    a <= signed(get_ram_data(ram_read_out(0)));
                    b <= signed(get_ram_data(ram_read_out(1)));
                    c <= signed(get_ram_data(ram_read_out(2)));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(instr_pipeline(4)) is
                WHEN add | sub | mpy_add =>
                    write_data_to_ram(ram_write_in , get_dest(instr_pipeline(4)), std_logic_vector(mpy_res(14+31 downto 14)));
                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
