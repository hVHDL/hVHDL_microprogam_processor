LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.execution_unit_pkg.all;
    use work.microprogram_interface_pkg.address_width;
    use work.microprogram_interface_pkg.jump_delay_slots;
    use work.microprogram_interface_pkg.program_start_array;

-- the program and data rams take their sizes and word widths from the
-- initial contents g_program and g_data, a power of 2 words each
entity microprogram_core is
    generic(
            g_program : work.dual_port_ram_pkg.ram_array
            ;g_data   : work.dual_port_ram_pkg.ram_array
            -- the rams' output registers : without the program ram's, a
            -- jump has 2 delay slots instead of 3 ; without the data ram's
            -- the operands arrive a clock earlier, the execution unit's
            -- g_data_ram_output_register must match
            ;g_program_ram_output_register : boolean := true
            ;g_data_ram_output_register    : boolean := true
            -- the sequencer's program cache, jump_delay_slots()
            -- instructions a line, a start from it that many clocks
            -- sooner : g_program_cache, g_dynamic_lines dynamic lines for
            -- the programs last started ; g_cached_programs, the programs at these
            -- addresses cached from the start, their lines fixed from
            -- g_program
            -- the data ram's writes forwarded to the reads that would miss
            -- them, execution_unit_pkg's forwarded_clocks() off the result
            -- latencies
            ;g_data_forwarding : boolean := false
            ;g_program_cache   : boolean := false
            ;g_dynamic_lines   : positive := 1
            ;g_cached_programs : program_start_array := (1 to 0 => 0)
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

    -- an instruction's address fields must not reach past the data ram

    signal instr_ram_read_in   : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out  : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in  : instr_ref_subtype.ram_write_in'subtype;

    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    signal data_ram_read_out : ref_subtype.ram_read_out'subtype;
    -- and the words to the execution units, forwarded or from the ram
    signal unit_read_out     : ref_subtype.ram_read_out'subtype;

    -- data forwarding : for each read port and each clock of the ram's
    -- read latency, the address read and the latest write to it since
    constant read_latency : natural := data_read_latency(g_data_ram_output_register);
    subtype data_word is std_logic_vector(g_data(g_data'low)'length-1 downto 0);
    type forward_record is record
        address : natural;
        hit     : boolean;
        data    : data_word;
    end record;
    type forward_array is array (natural range <>, natural range <>) of forward_record;
    signal forward : forward_array(0 to to_unit.data_read_out'length-1, 0 to read_latency-1)
        := (others => (others => (address => 0, hit => false, data => (others => '0'))));

    constant instruction_width : natural := g_program(g_program'low)'length;
    signal instr_pipeline : instruction_pipeline_array(0 to pipeline_high)(instruction_width-1 downto 0)
        := (0 to pipeline_high => encode(mi(nop), instruction_width));

    signal write_buffer : mc_write_in'subtype := idle_write;

    -- the instruction going out of the sequencer, from its cache or the ram
    signal instruction_read_out : instr_ref_subtype.ram_read_out'subtype;

    function cache_depth return natural is
    begin
        if g_program_cache or g_cached_programs'length > 0 then
            return jump_delay_slots(g_program_ram_output_register);
        end if;
        return 0;
    end cache_depth;

    -- the cached programs' first instructions, cache_depth a program
    function static_words return work.dual_port_ram_pkg.ram_array is
        variable retval : work.dual_port_ram_pkg.ram_array(0 to maximum(g_cached_programs'length * cache_depth, 1) - 1)
            (instruction_width-1 downto 0) := (others => encode(mi(nop), instruction_width));
        variable start : natural;
    begin
        for line in 0 to g_cached_programs'length-1 loop
            start := g_cached_programs(g_cached_programs'low + line);
            for word in 0 to cache_depth-1 loop
                retval(line * cache_depth + word) := g_program(g_program'low + (start + word) mod g_program'length);
            end loop;
        end loop;
        return retval;
    end static_words;

begin

    assert address_bits(instruction_width) <= address_width(g_data'length)
        report "the " & integer'image(instruction_width) & " bit instructions' "
            & integer'image(address_bits(instruction_width)) & " bit address fields reach past the "
            & integer'image(g_data'length) & " word data ram" severity failure;

----------------------------------------------------------
    to_unit <= (data_read_out        => unit_read_out
                       , instr_ram_read_out => instruction_read_out
                       , instr_pipeline     => instr_pipeline);

    mc_output <= ram_write_in;
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(g_program_size => g_program'length, g_instruction_width => instruction_width
        , g_cache_depth => cache_depth, g_dynamic_lines => g_dynamic_lines * boolean'pos(g_program_cache)
        , g_static_starts => g_cached_programs, g_static_words => static_words)
    port map(clock 
    , instruction_ram_read_in  => instr_ram_read_in(0)
    , instruction_ram_read_out => instr_ram_read_out(0)
    , processor_enabled        => mproc_out.is_busy
    , instr_pipeline           => instr_pipeline
    , processor_requested      => mproc_in.processor_requested
    , start_address            => mproc_in.start_address
    , is_ready                 => mproc_out.is_ready
    , instruction_read_out     => instruction_read_out(0));
----------------------------------------------------------
    u_program_ram : entity work.multi_port_ram
    generic map(g_program, g_program_ram_output_register)
    port map(
        clock => clock
        ,ram_read_in  => instr_ram_read_in(0 to 0)
        ,ram_read_out => instr_ram_read_out(0 to 0)
        ,ram_write_in => instr_ram_write_in);
----
    u_data_ram : entity work.multi_port_ram
    generic map(g_data, g_data_ram_output_register)
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
    -- a read samples its address in stage 0 and its word leaves the ram
    -- read_latency clocks later : a write to the address in the clock of
    -- the read, which the ram leaves undefined, or in a clock after it
    -- before the word leaves, which the word misses, replaces the word
    forward_writes : process(clock) is
        constant ports : natural := to_unit.data_read_out'length;
        variable write_address : natural;
    begin
        if rising_edge(clock) then
            write_address := to_integer(ram_write_in.address);
            for p in 0 to ports-1 loop
                forward(p, 0).address <= to_integer(from_unit.data_read_in(p).address);
                forward(p, 0).hit     <= false;
                if ram_write_in.write_requested = '1'
                    and write_address = to_integer(from_unit.data_read_in(p).address)
                then
                    forward(p, 0).hit  <= true;
                    forward(p, 0).data <= ram_write_in.data;
                end if;
                for stage in 1 to read_latency-1 loop
                    forward(p, stage) <= forward(p, stage-1);
                    if ram_write_in.write_requested = '1' and write_address = forward(p, stage-1).address then
                        forward(p, stage).hit  <= true;
                        forward(p, stage).data <= ram_write_in.data;
                    end if;
                end loop;
            end loop;
        end if;
    end process forward_writes;

    forward_reads : process(all) is
    begin
        unit_read_out <= data_ram_read_out;
        if g_data_forwarding then
            for p in 0 to to_unit.data_read_out'length-1 loop
                if forward(p, read_latency-1).hit then
                    unit_read_out(p).data <= forward(p, read_latency-1).data;
                end if;
            end loop;
        end if;
    end process forward_reads;

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
