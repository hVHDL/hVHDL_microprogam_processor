LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

-- g_program_size : the program ram's words, the program counter wraps
-- around at its end and start and jump addresses are taken modulo it
--
-- g_cache_depth > 0 : a one line program cache. On a start the program's
-- address is compared with the line's : on a hit the line's
-- g_cache_depth instructions go out from the next clock while the
-- program counter starts that many instructions on, on a miss the program
-- starts from the ram and its first g_cache_depth instructions fill the
-- line for the next start. A program with a jump (its delay slots would
-- differ) or a program_end (it would end the run while the line goes
-- out) among them is not cached ; set_rpt takes effect as it goes out,
-- from either. With g_cache_depth the ram's fetch latency,
-- microprogram_interface_pkg's jump_delay_slots(), a hit takes that many
-- clocks off the start. instruction_read_out is the instruction going
-- out, from the line or the ram, for the execution units.
entity microprogram_sequencer is
    generic(
        g_program_size : positive := 1024
        -- the program ram's word width
        ;g_instruction_width : positive := 32
        ;g_cache_depth : natural := 0
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

    -- the program cache line
    constant depth : natural := g_cache_depth;
    type word_array is array (natural range <>) of std_logic_vector(g_instruction_width-1 downto 0);
    signal cache_words : word_array(0 to maximum(depth, 1)-1) := (others => nop_instruction);
    signal cache_tag   : natural range 0 to g_program_size-1 := 0;
    signal cache_valid : boolean := false;
    signal filling     : boolean := false;
    signal fill_count  : natural range 0 to maximum(depth, 1) := 0;
    signal serving     : boolean := false;
    signal serve_count : natural range 0 to maximum(depth, 1) := 0;
    -- the line's instruction going out, and the one going out from either
    signal cache_out   : instruction_ram_read_out'subtype := (data => nop_instruction, data_is_ready => '0');
    signal read_out    : instruction_ram_read_out'subtype;

    function is_control (instruction : std_logic_vector) return boolean is
    begin
        return decode(instruction) = jump or decode(instruction) = program_end;
    end is_control;

begin

    read_out <= cache_out when serving else instruction_ram_read_out;
    instruction_read_out <= read_out;

    processor_enabled <= (processor_state = running);
    instr_pipeline    <= pipeline;

    make_program_counter : process(clock)
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
                    cache_out   <= (data => cache_words(serve_count), data_is_ready => '1');
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
                        if depth > 0 and cache_valid and cache_tag = start_address mod g_program_size then
                            -- hit : the line goes out from the next clock
                            program_counter <= (start_address + depth) mod g_program_size;
                            cache_out       <= (data => cache_words(0), data_is_ready => '1');
                            serving         <= true;
                            serve_count     <= 1;
                        else
                            program_counter <= start_address mod g_program_size;
                            if depth > 0 then
                                -- miss : fill the line from the ram
                                cache_tag   <= start_address mod g_program_size;
                                cache_valid <= false;
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
                            cache_words(fill_count) <= get_ram_data(instruction_ram_read_out);
                            fill_count <= fill_count + 1;
                            if fill_count = depth - 1 then
                                filling     <= false;
                                cache_valid <= true;
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

