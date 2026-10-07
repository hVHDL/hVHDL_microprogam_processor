LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.address_width;

-- the program and data rams take their sizes and word widths from the
-- initial contents g_program and g_data, a power of 2 words each
entity fixed_microprogram_processor is
    generic(
            g_number_of_pipeline_stages : natural := 10
            ;g_used_radix               : natural
            ;g_program                  : work.dual_port_ram_pkg.ram_array
            ;g_data                     : work.dual_port_ram_pkg.ram_array
           );
    port(
        clock        : in std_logic
        ;mproc_in    : in work.microprogram_interface_pkg.microprogram_processor_in_record
        ;mproc_out   : out work.microprogram_interface_pkg.microprogram_processor_out_record
        ;mc_read_in  : out ram_read_in_array
        ;mc_read_out : in ram_read_out_array
        ;mc_output   : out ram_write_in_record
        ;mc_write_in : in ram_write_in_record := init_write_in(address_width(g_data'length), g_data(g_data'low)'length)
    );
end fixed_microprogram_processor;

architecture rtl of fixed_microprogram_processor is

    constant ref_subtype : subtype_ref_record := create_ref_subtypes(
        readports     => 3
        ,datawidth    => g_data(g_data'low)'length
        ,addresswidth => address_width(g_data'length));
    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(
        readports     => 1
        ,datawidth    => g_program(g_program'low)'length
        ,addresswidth => address_width(g_program'length));

    constant idle_write : ref_subtype.ram_write_in'subtype := ref_subtype.ram_write_in;

    signal instr_ram_read_in   : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out  : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in  : instr_ref_subtype.ram_write_in'subtype;

    signal ram_read_in : ref_subtype.ram_read_in'subtype;
    signal sub_read_in : ref_subtype.ram_read_in'subtype;

    signal ram_write_in      : ref_subtype.ram_write_in'subtype;
    signal add_sub_ram_write : ref_subtype.ram_write_in'subtype;

    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal data_ram_read_out : ref_subtype.ram_read_out'subtype;

    signal command        : t_command                  := (program_end);
    constant instruction_width : natural := g_program(g_program'low)'length;
    constant nop_instruction : std_logic_vector(instruction_width-1 downto 0) := encode(mi(nop), instruction_width);
    signal instr_pipeline : instruction_pipeline_array(0 to g_number_of_pipeline_stages-1)(instruction_width-1 downto 0)
        := (0 to g_number_of_pipeline_stages-1 => nop_instruction);

    signal write_buffer : mc_write_in'subtype := idle_write;

    use work.execution_unit_pkg.all;
    constant unit_in_ref : execution_unit_in_record := (
        instr_ram_read_out => instr_ref_subtype.ram_read_out
        ,data_read_out     => ref_subtype.ram_read_out
        ,instr_pipeline    => (0 to g_number_of_pipeline_stages-1 => nop_instruction)
        );

    constant unit_out_ref : execution_unit_out_record := (
        data_read_in  => ref_subtype.ram_read_in
        ,ram_write_in => ref_subtype.ram_write_in
        );

    signal unit_in : unit_in_ref'subtype := unit_in_ref;
    signal unit_out : unit_out_ref'subtype := unit_out_ref;

begin

----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(g_program_size => g_program'length, g_instruction_width => instruction_width)
    port map(clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => mproc_out.is_busy
    , instr_pipeline      => instr_pipeline
    , processor_requested => mproc_in.processor_requested
    , start_address       => mproc_in.start_address
    , is_ready            => mproc_out.is_ready);
----------------------------------------------------------
----
    u_program_ram : entity work.multi_port_ram
    generic map(g_program)
    port map(
        clock => clock
        ,ram_read_in  => instr_ram_read_in(0 to 0)
        ,ram_read_out => instr_ram_read_out(0 to 0)
        ,ram_write_in => instr_ram_write_in);
----
    u_data_ram : entity work.multi_port_ram
    generic map(g_data)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);

---------------------------------------
---------------------------------------
    fixed_mult_acc : entity work.execution_unit(fixed_mult_acc)
    generic map(g_radix => g_used_radix)
    port map(clock 
    ,unit_in
    ,unit_out);

    unit_in <= (data_ram_read_out, instr_ram_read_out, instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
    combine_ram_buses : process(all) is
    begin
        -- if rising_edge(clock)
        -- then
            mc_read_in   <= combine((0 => unit_out.data_read_in) , ref_subtype.address , no_map_range_low => 0   , no_map_range_hi => 118);
            ram_read_in  <= combine((0 => unit_out.data_read_in) , ref_subtype.address , no_map_range_low => 119 , no_map_range_hi => 127);

            ram_write_in <= combine((0 => unit_out.ram_write_in));

            -- add buffering for writing ram externally when not written by processor
            -- if write_requested(ram_write_in) then
            --     write_buffer <= ram_write_in;
            -- end if;

            -- if not write_requested(add_sub_ram_write)
            -- then
            --     if write_requested(ram_write_in) 
            --         or write_requested(write_buffer)
            --     then
            --         ram_write_in <= combine((0 => mc_write_in));
            --     end if;
            -- end if;

            for i in ram_read_out'range loop
                if mc_read_out(i).data_is_ready then
                    data_ram_read_out(i).data          <= mc_read_out(i).data;
                    data_ram_read_out(i).data_is_ready <= mc_read_out(i).data_is_ready;
                else
                    data_ram_read_out(i) <= ram_read_out(i);
                end if;
            end loop;
        -- end if;
    end process combine_ram_buses;

    mc_output <= ram_write_in;

-------------------------------
end rtl;
