architecture float_mult_add of instruction is

    use work.real_to_fixed_pkg.all;
    use work.float_typedefs_generic_pkg.all;
    use work.multiply_add_pkg.all;
    constant mpya_ref : mpya_subtype_record := create_mpya_typeref(8,24);
    signal mpya_in  : mpya_ref.mpya_in'subtype  := mpya_ref.mpya_in;
    signal mpya_out : mpya_ref.mpya_out'subtype := mpya_ref.mpya_out;

    constant datawidth : natural := instruction_in.data_read_out(instruction_in.data_read_out'left).data'length;

begin
    ---------------------------
    u_float_mpy_add : entity work.multiply_add
    port map(
        clock
        ,mpya_in
        ,mpya_out
    );
    ---------------------------
    float_mpy_add : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(instruction_out.data_read_in);
            init_mp_write(instruction_out.ram_write_in);

            init_multiply_add(mpya_in);

            ---------------
            if ram_read_is_ready(instruction_in.instr_ram_read_out(0)) then
                CASE decode(get_ram_data(instruction_in.instr_ram_read_out(0))) is
                    WHEN mpy_add 
                        | mpy_sub 
                        | neg_mpy_add 
                        | neg_mpy_sub 
                        =>

                        request_data_from_ram(instruction_out.data_read_in(arg1_mem)
                            , get_arg1(get_ram_data(instruction_in.instr_ram_read_out(0))));

                        request_data_from_ram(instruction_out.data_read_in(arg2_mem)
                            , get_arg2(get_ram_data(instruction_in.instr_ram_read_out(0))));

                        request_data_from_ram(instruction_out.data_read_in(arg3_mem)
                            , get_arg3(get_ram_data(instruction_in.instr_ram_read_out(0))));

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------

            CASE decode(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay+g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    -- multiply_add(mpya_in
                    -- ,(31 downto 0 => '0')
                    -- ,(31 downto 0 => '0')
                    -- ,(31 downto 0 => '0'));

                WHEN neg_mpy_add =>
                    -- multiply_add(mpya_in
                    -- ,get_ram_data(instruction_in.data_read_out(arg1_mem))
                    -- ,get_ram_data(instruction_in.data_read_out(arg2_mem))
                    -- ,get_ram_data(instruction_in.data_read_out(arg3_mem)));

                WHEN neg_mpy_sub =>
                    -- multiply_add(mpya_in
                    -- ,get_ram_data(instruction_in.data_read_out(arg1_mem));
                    -- ,get_ram_data(instruction_in.data_read_out(arg2_mem));
                    -- ,get_ram_data(instruction_in.data_read_out(arg3_mem));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays)) is
                WHEN mpy_add 
                    | neg_mpy_add   
                    | neg_mpy_sub   
                    | mpy_sub
                    =>

                    -- write_data_to_ram(instruction_out.ram_write_in 
                    -- , get_dest(instruction_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays))
                    -- , std_logic_vector(mpy_res(radix+instruction_in.data_read_out(instruction_in.data_read_out'left).data'length-1 downto radix)));

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process float_mpy_add;

end float_mult_add;
