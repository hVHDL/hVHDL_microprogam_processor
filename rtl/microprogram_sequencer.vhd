LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

-- g_program_size : the program ram's words, the program counter wraps
-- around at its end and start and jump addresses are taken modulo it
entity microprogram_sequencer is
    generic(
        g_program_size : positive := 1024
        -- the program ram's word width
        ;g_instruction_width : positive := 32
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
    );
end entity microprogram_sequencer;

architecture rtl of microprogram_sequencer is

    signal program_counter : natural range 0 to g_program_size-1 := 0;
    -- set_rpt's count, the low 21 bits of its argument
    signal rpt_counter     : natural range 0 to 2**21-1 := 0;

    type t_processor_states is (halted, running);
    signal processor_state : t_processor_states := halted;

    -- nop from power up : an all zero instruction is mpy_add to address 0
    constant nop_instruction : std_logic_vector(g_instruction_width-1 downto 0) := resize_instruction(op(nop), g_instruction_width);
    signal pipeline : instr_pipeline'subtype := (others => nop_instruction);

begin

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
                                     
            CASE processor_state is
                WHEN halted =>

                    if processor_requested 
                    then
                        program_counter <= start_address mod g_program_size;
                        processor_state <= running;
                    end if;

                WHEN running =>

                    request_data_from_ram(instruction_ram_read_in, program_counter);
                    program_counter <= (program_counter + 1) mod g_program_size;

                    ---
                    if ram_read_is_ready( instruction_ram_read_out )
                        and decode(get_ram_data(instruction_ram_read_out)) = program_end
                    then
                        processor_state <= halted;
                        is_ready <= true;
                    end if;

                    ---
                    if ram_read_is_ready(instruction_ram_read_out)
                        and decode(get_ram_data(instruction_ram_read_out)) /= program_end
                    then
                            pipeline(0) <= get_ram_data(instruction_ram_read_out);
                    end if;
                    ---
            end CASE;

            ------------ jump instruction ----------------
            if processor_enabled and ram_read_is_ready(instruction_ram_read_out) 
            then
                CASE decode(get_ram_data(instruction_ram_read_out)) is
                    when jump =>
                        if rpt_counter > 0 then
                            rpt_counter <= rpt_counter - 1;
                            program_counter <= get_single_argument(get_ram_data(instruction_ram_read_out)) mod g_program_size;
                        end if;
                    WHEN set_rpt =>
                        rpt_counter <= get_single_argument(get_ram_data(instruction_ram_read_out));
                    when others => --do nothing
                end CASE;
            end if;
            ----------------------------------------------

        end if; -- rising_edge
    end process make_program_counter;	
------------------------------------------------------------------------
end rtl;

