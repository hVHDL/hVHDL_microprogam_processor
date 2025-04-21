LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

entity instruction is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
        ;package mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
        ;arg1_mem : natural := 1
        ;arg2_mem : natural := 2
        ;arg3_mem : natural := 3
        ;inst_mem : natural := 4
        ;radix    : natural := 14
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

    signal a, b, c , cbuf: signed(register_bit_width-1 downto 0);
    signal mpy_res : signed(2*register_bit_width-1 downto 0);
    signal mpy_res2 : signed(2*register_bit_width-1 downto 0);

begin

    mpy_add_sub : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(ram_read_in);
            init_mp_write(ram_write_in);

            ---------------
            if ram_read_is_ready(ram_read_out(inst_mem)) then
                CASE decode(get_ram_data(ram_read_out(inst_mem))) is
                    WHEN add =>
                        request_data_from_ram(ram_read_in(arg2_mem)
                        , get_arg1(get_ram_data(ram_read_out(inst_mem))));

                        request_data_from_ram(ram_read_in(arg3_mem)
                        , get_arg2(get_ram_data(ram_read_out(inst_mem))));

                    WHEN sub =>
                        request_data_from_ram(ram_read_in(arg2_mem)
                        , get_arg1(get_ram_data(ram_read_out(inst_mem))));

                        request_data_from_ram(ram_read_in(arg3_mem)
                        , get_arg2(get_ram_data(ram_read_out(inst_mem))));

                    WHEN mpy_add =>
                        request_data_from_ram(ram_read_in(arg1_mem)
                        , get_arg1(get_ram_data(ram_read_out(inst_mem))));

                        request_data_from_ram(ram_read_in(arg3_mem)
                        , get_arg2(get_ram_data(ram_read_out(inst_mem))));

                        request_data_from_ram(ram_read_in(arg2_mem)
                        , get_arg3(get_ram_data(ram_read_out(inst_mem))));

                    WHEN others => -- do nothing
                end CASE;
            end if;
            ---------------
            mpy_res2 <= a * b;
            cbuf     <= c;
            mpy_res  <= mpy_res2 + shift_left(resize(cbuf , mpy_res'length), radix) ;


            CASE decode(instr_pipeline(mp_ram_pkg.read_pipeline_delay)) is
                WHEN add =>
                    a <= to_fixed(1.0, a'length, radix);
                    b <= signed(get_ram_data(ram_read_out(arg3_mem)));
                    c <= signed(get_ram_data(ram_read_out(arg2_mem)));

                WHEN sub =>
                    a <= to_fixed(1.0, a'length, radix);
                    b <=  signed(get_ram_data(ram_read_out(arg3_mem)));
                    c <= -signed(get_ram_data(ram_read_out(arg2_mem)));

                WHEN mpy_add =>
                    a <= signed(get_ram_data(ram_read_out(arg1_mem)));
                    b <= signed(get_ram_data(ram_read_out(arg3_mem)));
                    c <= signed(get_ram_data(ram_read_out(arg2_mem)));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(instr_pipeline(mp_ram_pkg.read_pipeline_delay + 3)) is
                WHEN add | sub | mpy_add =>
                    write_data_to_ram(ram_write_in , get_dest(instr_pipeline(mp_ram_pkg.read_pipeline_delay + 3)), std_logic_vector(mpy_res(14+31 downto 14)));
                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
