architecture float_mult_add of execution_unit is

    use work.real_to_fixed_pkg.all;
    use work.float_typedefs_generic_pkg.all;
    use work.float_to_real_conversions_pkg.all;
    use work.multiply_add_pkg.all;
    constant datawidth : natural := unit_in.data_read_out(unit_in.data_read_out'left).data'length;

    function to_hfloat is new to_hfloat_generic generic map(exponent_length => 8, word_length => datawidth);
    constant hfloat_ref : hfloat_record := to_hfloat(0.0);
    constant mpya_ref : mpya_subtype_record := create_mpya_typeref(hfloat_ref);
    signal mpya_in  : mpya_ref.mpya_in'subtype  := mpya_ref.mpya_in;
    signal mpya_out : mpya_ref.mpya_out'subtype := mpya_ref.mpya_out;


begin
    ---------------------------
    addsub_gen : 
    if g_option = "hfloat" generate
        u_float_mpy_add : entity work.multiply_add(hfloat)
        generic map(hfloat_ref)
        port map(
            clock
            ,mpya_in
            ,mpya_out
        );
    elsif g_option = "fast_hfloat" generate
        u_float_mpy_add : entity work.multiply_add(fast_hfloat)
        generic map(hfloat_ref) -- note needs to have 8 bit exponent and 32 bit word length
        port map(
            clock
            ,mpya_in
            ,mpya_out
        );
    elsif g_option = "agilex" generate
        u_float_mpy_add : entity work.multiply_add(agilex)
        generic map(hfloat_ref) -- note needs to have 8 bit exponent and 32 bit word length
        port map(
            clock
            ,mpya_in
            ,mpya_out
        );
    end generate;
    ---------------------------
    float_mpy_add : process(clock) is
        function "-" (a : std_logic_vector) return std_logic_vector is
            variable retval : a'subtype := a;
        begin
            retval(retval'left) := not retval(retval'left);
            return retval;
        end function;

    begin
        if rising_edge(clock) then
            init_mp_ram_read(unit_out.data_read_in);
            init_mp_write(unit_out.ram_write_in);

            -- init_multiply_add(mpya_in);

            ---------------
            if ram_read_is_ready(unit_in.instr_ram_read_out(0)) then
                CASE decode(get_ram_data(unit_in.instr_ram_read_out(0))) is
                    WHEN 
                      mpy_add 
                    | mpy_sub 
                    | neg_mpy_add 
                    | neg_mpy_sub 
                    =>

                        request_data_from_ram(unit_out.data_read_in(g_arg1_port)
                            , get_arg1(get_ram_data(unit_in.instr_ram_read_out(0))));

                        request_data_from_ram(unit_out.data_read_in(g_arg2_port)
                            , get_arg2(get_ram_data(unit_in.instr_ram_read_out(0))));

                        request_data_from_ram(unit_out.data_read_in(g_arg3_port)
                            , get_arg3(get_ram_data(unit_in.instr_ram_read_out(0))));

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------
            multiply_add(mpya_in,to_std_logic(hfloat_ref), to_std_logic(hfloat_ref), to_std_logic(hfloat_ref));

            CASE decode(unit_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay+g_read_delays + g_read_out_delays)) is
                WHEN mpy_add =>
                    multiply_add(mpya_in
                    ,get_ram_data(unit_in.data_read_out(g_arg1_port))
                    ,get_ram_data(unit_in.data_read_out(g_arg2_port))
                    ,get_ram_data(unit_in.data_read_out(g_arg3_port)));

                WHEN mpy_sub =>
                    multiply_add(mpya_in
                    ,get_ram_data(unit_in.data_read_out(g_arg1_port))
                    ,get_ram_data(unit_in.data_read_out(g_arg2_port))
                    ,-get_ram_data(unit_in.data_read_out(g_arg3_port)));

                WHEN neg_mpy_add =>
                    multiply_add(mpya_in
                    ,-get_ram_data(unit_in.data_read_out(g_arg1_port))
                    ,get_ram_data(unit_in.data_read_out(g_arg2_port))
                    ,get_ram_data(unit_in.data_read_out(g_arg3_port)));

                WHEN neg_mpy_sub =>
                    multiply_add(mpya_in
                    ,-get_ram_data(unit_in.data_read_out(g_arg1_port))
                    ,get_ram_data(unit_in.data_read_out(g_arg2_port))
                    ,-get_ram_data(unit_in.data_read_out(g_arg3_port)));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(unit_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + g_instruction_delay + g_read_delays+ g_read_out_delays)) is
                WHEN mpy_add 
                    | neg_mpy_add   
                    | neg_mpy_sub   
                    | mpy_sub
                    =>

                    write_data_to_ram(unit_out.ram_write_in 
                    , get_dest(unit_in.instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + g_instruction_delay + g_read_delays+ g_read_out_delays))
                    , get_mpya_result(mpya_out));

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process float_mpy_add;

end float_mult_add;
