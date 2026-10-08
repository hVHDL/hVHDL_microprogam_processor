LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.microprogram_interface_pkg.program_start_array;

-- g_program_size : the program ram's words, the program counter wraps
-- around at its end and start and jump addresses are taken modulo it
--
-- g_cache_depth > 0 : a program cache of lines of g_cache_depth
-- instructions. On a start the program's address is compared with the
-- lines' : on a hit the line's instructions go out from the next clock
-- while the program counter starts g_cache_depth instructions on, on a
-- miss the program starts from the ram. With g_cache_depth the ram's
-- fetch latency, microprogram_interface_pkg's jump_delay_slots(), a hit
-- takes that many clocks off the start. The lines :
--
--   static : the programs at g_static_starts, their first instructions
--       g_static_words (g_cache_depth a program, in g_static_starts'
--       order) fixed at elaboration, a hit from the first start on
--   dynamic, g_dynamic_lines of them : the first instructions of the
--       programs last started that have no static line, each line filled
--       on its program's miss for the next start. A miss takes the lines
--       in turn (round robin), whatever their use : with n lines, n
--       programs started in any order stay cached, a start of an n+1th
--       replaces the line filled longest ago
--
-- A program with a jump (its delay slots would differ) or a program_end
-- (it would end the run while the line goes out) among its first
-- instructions is not cached : a static one fails elaboration, a dynamic
-- one is not filled. set_rpt takes effect as it goes out, from either.
-- instruction_read_out is the instruction going out, from a line or the
-- ram, for the execution units.
entity microprogram_sequencer is
    generic(
        g_program_size : positive := 1024
        -- the program ram's word width
        ;g_instruction_width : positive := 32
        ;g_cache_depth : natural := 0
        ;g_dynamic_lines : natural := 1
        ;g_static_starts : program_start_array := (1 to 0 => 0)
        ;g_static_words  : work.dual_port_ram_pkg.ram_array := (0 to 0 => (g_instruction_width-1 downto 0 => '0'))
    );
    port(
        clock : in std_logic

        ;instruction_ram_read_in  : out ram_read_in_record
        ;instruction_ram_read_out : in ram_read_out_record

        ;processor_enabled   : out boolean
        ;instr_pipeline      : out instruction_pipeline_array
        ;processor_requested : in boolean := true
        ;start_address       : in natural := 0
        ;is_ready            : out boolean
        ;instruction_read_out : out ram_read_out_record
    );
end entity microprogram_sequencer;

architecture rtl of microprogram_sequencer is

    signal program_counter : natural range 0 to g_program_size-1 := 0;
    -- set_rpt's count, its argument fields
    signal rpt_counter     : natural range 0 to 2**single_argument_bits(g_instruction_width)-1 := 0;

    type t_processor_states is (halted, running);
    signal processor_state : t_processor_states := halted;

    -- nop from power up : an all zero instruction is mpy_add to address 0
    constant nop_instruction : std_logic_vector(g_instruction_width-1 downto 0) := encode(mi(nop), g_instruction_width);
    signal pipeline : instr_pipeline'subtype := (others => nop_instruction);

    -- the program cache
    constant depth : natural := g_cache_depth;
    type word_array is array (natural range <>) of std_logic_vector(g_instruction_width-1 downto 0);

    -- the static lines 0 to static_lines-1, the dynamic ones after them
    constant static_lines  : natural := g_static_starts'length * boolean'pos(depth > 0);
    constant dynamic_lines : natural := g_dynamic_lines * boolean'pos(depth > 0);
    constant dynamic_line  : natural := static_lines; -- the first
    constant line_count    : natural := static_lines + dynamic_lines;

    function static_start (line : natural) return natural is
    begin
        return g_static_starts(g_static_starts'low + line) mod g_program_size;
    end static_start;

    function static_word (line, word : natural) return std_logic_vector is
    begin
        return g_static_words(g_static_words'low + line * depth + word);
    end static_word;

    -- the static line of a start address, static_lines for none
    function static_line_of (address : natural) return natural is
    begin
        for line in 0 to static_lines-1 loop
            if static_start(line) = address mod g_program_size then
                return line;
            end if;
        end loop;
        return dynamic_line;
    end static_line_of;

    subtype line_words is word_array(0 to maximum(depth, 1)-1);
    type line_array is array (natural range <>) of line_words;
    type tag_array is array (natural range <>) of natural range 0 to g_program_size-1;
    type flag_array is array (natural range <>) of boolean;
    -- the dynamic lines, their programs' start addresses and whether filled
    signal cache_words : line_array(0 to maximum(dynamic_lines, 1)-1) := (others => (others => nop_instruction));
    signal cache_tags  : tag_array(0 to maximum(dynamic_lines, 1)-1) := (others => 0);
    signal cache_valid : flag_array(0 to maximum(dynamic_lines, 1)-1) := (others => false);
    -- the dynamic line the next miss takes, the one filling
    signal next_line   : natural range 0 to maximum(dynamic_lines, 1)-1 := 0;
    signal fill_line   : natural range 0 to maximum(dynamic_lines, 1)-1 := 0;
    signal filling     : boolean := false;
    signal fill_count  : natural range 0 to maximum(depth, 1) := 0;
    signal serving     : boolean := false;
    signal serve_count : natural range 0 to maximum(depth, 1) := 0;
    signal serve_line  : natural range 0 to maximum(line_count, 1)-1 := 0;
    -- the line's instruction going out, and the one going out from either
    signal cache_out   : instruction_ram_read_out'subtype := (data => nop_instruction, data_is_ready => '0');
    signal read_out    : instruction_ram_read_out'subtype;

    function is_control (instruction : std_logic_vector) return boolean is
    begin
        return decode(instruction) = jump or decode(instruction) = program_end;
    end is_control;

    -- a word of a line, static or dynamic
    function line_word (line, word : natural; dynamic_words : line_array) return std_logic_vector is
    begin
        if line < static_lines then
            return static_word(line, word);
        end if;
        return dynamic_words(line - static_lines)(word);
    end line_word;

    -- the static lines' programs have no jump or program_end in them
    function static_lines_check return boolean is
    begin
        for line in 0 to static_lines-1 loop
            for word in 0 to depth-1 loop
                assert not is_control(static_word(line, word))
                    report "microprogram_sequencer : the program at " & integer'image(static_start(line))
                        & " has a jump or a program_end in its first " & integer'image(depth)
                        & " instructions and cannot be cached"
                    severity failure;
            end loop;
        end loop;
        return true;
    end static_lines_check;
    constant static_lines_checked : boolean := static_lines_check;

begin

    assert g_static_starts'length = 0 or depth > 0
        report "microprogram_sequencer : static cache lines need g_cache_depth > 0" severity failure;
    assert g_static_words'length >= static_lines * depth
        report "microprogram_sequencer : g_static_words holds fewer than g_cache_depth words a static line"
        severity failure;

    read_out <= cache_out when serving else instruction_ram_read_out;
    instruction_read_out <= read_out;

    processor_enabled <= (processor_state = running);
    instr_pipeline    <= pipeline;

    make_program_counter : process(clock)
        -- the start's line, line_count for none
        variable hit_line : natural range 0 to line_count;
    begin
        if rising_edge(clock) then
            init_mp_ram_read(instruction_ram_read_in);
            -------- instruction pipeline --------
            pipeline <= nop_instruction & pipeline(0 to pipeline'high-1);
            --------------------------------------
            is_ready <= false;

            ------------ the cache line going out ------------
            cache_out.data_is_ready <= '0';
            if serving then
                if serve_count < depth then
                    cache_out   <= (data => line_word(serve_line, serve_count, cache_words), data_is_ready => '1');
                    serve_count <= serve_count + 1;
                else
                    serving <= false;
                end if;
            end if;
            -- the ram's fetches start where the line ends and come out after it
            assert not (serving and ram_read_is_ready(instruction_ram_read_out))
                report "microprogram_sequencer : the ram's instruction meets the cache line's"
                severity failure;

            CASE processor_state is
                WHEN halted =>

                    if processor_requested
                    then
                        hit_line := line_count;
                        if static_line_of(start_address) < static_lines then
                            hit_line := static_line_of(start_address);
                        end if;
                        for line in 0 to dynamic_lines-1 loop
                            if cache_valid(line) and cache_tags(line) = start_address mod g_program_size then
                                hit_line := dynamic_line + line;
                            end if;
                        end loop;

                        if hit_line < line_count then
                            -- hit : the line goes out from the next clock
                            program_counter <= (start_address + depth) mod g_program_size;
                            cache_out       <= (data => line_word(hit_line, 0, cache_words), data_is_ready => '1');
                            serving         <= true;
                            serve_count     <= 1;
                            serve_line      <= hit_line;
                        else
                            program_counter <= start_address mod g_program_size;
                            if dynamic_lines > 0 then
                                -- miss : the next dynamic line fills from the ram
                                cache_tags(next_line)  <= start_address mod g_program_size;
                                cache_valid(next_line) <= false;
                                fill_line   <= next_line;
                                next_line   <= (next_line + 1) mod dynamic_lines;
                                filling     <= true;
                                fill_count  <= 0;
                            end if;
                        end if;
                        processor_state <= running;
                    end if;

                WHEN running =>

                    request_data_from_ram(instruction_ram_read_in, program_counter);
                    program_counter <= (program_counter + 1) mod g_program_size;

                    ---
                    if ram_read_is_ready(read_out)
                        and decode(get_ram_data(read_out)) = program_end
                    then
                        processor_state <= halted;
                        is_ready <= true;
                    end if;

                    ---
                    if ram_read_is_ready(read_out)
                        and decode(get_ram_data(read_out)) /= program_end
                    then
                            pipeline(0) <= get_ram_data(read_out);
                    end if;

                    -- the first instructions from the ram fill the line, a
                    -- program with a jump or program_end among them is not
                    -- cached
                    if filling and ram_read_is_ready(instruction_ram_read_out) then
                        if is_control(get_ram_data(instruction_ram_read_out)) then
                            filling <= false;
                        else
                            cache_words(fill_line)(fill_count) <= get_ram_data(instruction_ram_read_out);
                            fill_count <= fill_count + 1;
                            if fill_count = depth - 1 then
                                filling     <= false;
                                cache_valid(fill_line) <= true;
                            end if;
                        end if;
                    end if;
                    ---
            end CASE;

            ------------ jump instruction ----------------
            if processor_enabled and ram_read_is_ready(read_out)
            then
                CASE decode(get_ram_data(read_out)) is
                    when jump =>
                        if rpt_counter > 0 then
                            rpt_counter <= rpt_counter - 1;
                            program_counter <= get_single_argument(get_ram_data(read_out)) mod g_program_size;
                        end if;
                    WHEN set_rpt =>
                        rpt_counter <= get_single_argument(get_ram_data(read_out));
                    when others => --do nothing
                end CASE;
            end if;
            ----------------------------------------------

        end if; -- rising_edge
    end process make_program_counter;	
------------------------------------------------------------------------
end rtl;

