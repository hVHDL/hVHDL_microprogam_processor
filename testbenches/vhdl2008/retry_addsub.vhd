
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;

entity instruction is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
        ;arg1_mem      : natural := 0
        ;arg2_mem      : natural := 1
        ;arg3_mem      : natural := 2
        ;radix         : natural := 14
        ------ instruction encodings -------
        ;g_mpy_add       : natural := 0
        ;g_mpy_sub       : natural := 1
        ;g_neg_mpy_add   : natural := 2
        ;g_neg_mpy_sub   : natural := 3
        ;g_a_add_b_mpy_c : natural := 4
        ;g_a_sub_b_mpy_c : natural := 5
        ;g_lp_filter     : natural := 6
       );
    port(
        clock : in std_logic
        ;instruction_ram_read_out : in ram_read_out_record
        ;data_read_in             : out ram_read_in_array
        ;data_read_out            : in ram_read_out_array
        ;ram_write_in             : out ram_write_in_record
        ;instr_pipeline           : in microinstruction_pkg.instruction_pipeline_array
    );
    use microinstruction_pkg.all;
    use work.real_to_fixed_pkg.all;
end;

architecture add_sub_mpy of instruction is

    constant datawidth : natural := data_read_out(data_read_out'left).data'length;

    signal a, b, c , cbuf : signed(datawidth-1 downto 0);
    signal mpy_res        : signed(2*datawidth-1 downto 0);
    signal mpy_res2       : signed(2*datawidth-1 downto 0);

begin

    mpy_add_sub : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(data_read_in);
            init_mp_write(ram_write_in);

            ---------------
            if ram_read_is_ready(instruction_ram_read_out) then
                CASE decode(get_ram_data(instruction_ram_read_out)) is
                    WHEN mpy_add | neg_mpy_add | neg_mpy_sub | mpy_sub | a_add_b_mpy_c | a_sub_b_mpy_c | lp_filter =>

                        request_data_from_ram(data_read_in(arg1_mem)
                            , get_arg1(get_ram_data(instruction_ram_read_out)));

                        request_data_from_ram(data_read_in(arg2_mem)
                            , get_arg2(get_ram_data(instruction_ram_read_out)));

                        request_data_from_ram(data_read_in(arg3_mem)
                            , get_arg3(get_ram_data(instruction_ram_read_out)));

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------
            mpy_res2 <= a * b;
            cbuf     <= c;
            mpy_res  <= mpy_res2 + shift_left(resize(cbuf , mpy_res'length), radix) ;
            ---------------

            CASE decode(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay)) is
                WHEN mpy_add =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(data_read_out(arg3_mem)));

                WHEN neg_mpy_add =>
                    a <= signed( not get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(data_read_out(arg3_mem)));

                WHEN neg_mpy_sub =>
                    a <= signed( not get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed( not get_ram_data(data_read_out(arg3_mem)));

                WHEN mpy_sub =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed( not get_ram_data(data_read_out(arg3_mem)));

                WHEN a_add_b_mpy_c =>
                    a <=   signed(get_ram_data(data_read_out(arg1_mem)))
                         + signed(get_ram_data(data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN a_sub_b_mpy_c =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)))
                         + signed( not get_ram_data(data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN lp_filter =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)))
                         + signed( not get_ram_data(data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(data_read_out(arg3_mem)));
                    c <= signed(get_ram_data(data_read_out(arg2_mem)));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3)) is
                WHEN mpy_add | neg_mpy_add | neg_mpy_sub | mpy_sub | a_add_b_mpy_c |a_sub_b_mpy_c | lp_filter =>
                    write_data_to_ram(ram_write_in 
                    , get_dest(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3))
                    , std_logic_vector(mpy_res(radix+data_read_out(data_read_out'left).data'length-1 downto radix)));
                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
----
