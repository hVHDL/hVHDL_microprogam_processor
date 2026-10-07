LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.execution_unit_pkg.all;
    use work.microprogram_interface_pkg.address_width;

-- the program and data rams take their sizes and word widths from the
-- initial contents g_program and g_data, a power of 2 words each
entity microprogram_core is
    generic(
            g_program : work.dual_port_ram_pkg.ram_array
            ;g_data   : work.dual_port_ram_pkg.ram_array
           );
    port(
        clock        : in std_logic
        ;mproc_in    : in work.microprogram_interface_pkg.microprogram_processor_in_record
        ;mproc_out   : out work.microprogram_interface_pkg.microprogram_processor_out_record
        ;mc_output   : out ram_write_in_record
        ;mc_write_in : in ram_write_in_record := init_write_in(address_width(g_data'length), g_data(g_data'low)'length)
        ------ instruction entity connection
        ;to_unit  : out execution_unit_in_record
        ;from_unit : in execution_unit_out_record
    );
end microprogram_core;

architecture rtl of microprogram_core is

    constant pipeline_high : natural := to_unit.instr_pipeline'high;

    constant ref_subtype : subtype_ref_record := create_ref_subtypes(
        readports     => to_unit.data_read_out'length
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

    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    signal data_ram_read_out : ref_subtype.ram_read_out'subtype;

    constant instruction_width : natural := g_program(g_program'low)'length;
    signal instr_pipeline : instruction_pipeline_array(0 to pipeline_high)(instruction_width-1 downto 0)
        := (0 to pipeline_high => resize_instruction(op(nop), instruction_width));

    signal write_buffer : mc_write_in'subtype := idle_write;

begin

----------------------------------------------------------
    to_unit <= (data_read_out        => data_ram_read_out
                       , instr_ram_read_out => instr_ram_read_out
                       , instr_pipeline     => instr_pipeline);

    mc_output <= ram_write_in;
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(g_program_size => g_program'length, g_instruction_width => instruction_width)
    port map(clock 
    , instruction_ram_read_in  => instr_ram_read_in(0)
    , instruction_ram_read_out => instr_ram_read_out(0)
    , processor_enabled        => mproc_out.is_busy
    , instr_pipeline           => instr_pipeline
    , processor_requested      => mproc_in.processor_requested
    , start_address            => mproc_in.start_address
    , is_ready                 => mproc_out.is_ready);
----------------------------------------------------------
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
        ,ram_read_in  => from_unit.data_read_in
        ,ram_read_out => data_ram_read_out
        ,ram_write_in => ram_write_in);
------------------------------------------------------------------------
------------------------------------------------------------------------
    buffer_writes : process(clock) is
    begin
        if rising_edge(clock) 
        then
            if not write_requested(from_unit.ram_write_in) 
            and write_requested(write_buffer)
            then
                init_mp_write(write_buffer);
            end if;

            if write_requested(mc_write_in)
            and write_requested(from_unit.ram_write_in)
            then
                write_buffer <= mc_write_in;
            end if;

        end if;
    end process;
------------------------------------------------------------------------
    combine_ram_buses : process(all) is
    begin
        -- if rising_edge(clock)
        -- then
            ram_write_in <= combine((0 => from_unit.ram_write_in));

            if not write_requested(from_unit.ram_write_in)
            then
                if write_requested(write_buffer)
                then
                    ram_write_in <= combine((0 => write_buffer));
                elsif write_requested(mc_write_in)
                then
                    ram_write_in <= combine((0 => mc_write_in));
                end if;
            end if;
        -- end if;
    end process combine_ram_buses;

-------------------------------
end rtl;
