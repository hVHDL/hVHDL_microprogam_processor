LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

entity microprogram_sequencer is
    port(
        clock : in std_logic

        ;instruction_ram_read_in  : out ram_read_in_record
        ;instruction_ram_read_out : in ram_read_out_record

        ;processor_enabled   : out boolean
        ;instr_pipeline      : out instruction_pipeline_array
        ;processor_requested : in boolean := true
        ;start_address       : in natural := 0
    );
end entity microprogram_sequencer;

architecture rtl of microprogram_sequencer is

    signal program_counter : natural range 0 to 1023 := 0;
    signal rpt_counter     : natural range 0 to 2**20  := 0;

    type t_processor_states is (halted, running);
    signal processor_state : t_processor_states := halted;

begin

    processor_enabled <= (processor_state = running);

    make_program_counter : process(clock)

    begin
        if rising_edge(clock) then
            init_mp_ram_read(instruction_ram_read_in);

            -------- instruction pipeline --------
            instr_pipeline <= get_ram_data(instruction_ram_read_out) & instr_pipeline(0 to instr_pipeline'high-1);
            --------------------------------------
            CASE processor_state is
                WHEN halted =>

                    if processor_requested 
                    then
                        program_counter <= start_address;
                        processor_state <= running;
                    end if;

                WHEN running =>

                    request_data_from_ram(instruction_ram_read_in, program_counter);
                    program_counter <= program_counter + 1;

                    ---
                    if ram_read_is_ready( instruction_ram_read_out )
                        and decode(get_ram_data(instruction_ram_read_out)) = program_end
                    then
                        processor_state <= halted;
                    end if;

                    ---
                    if ram_read_is_ready(instruction_ram_read_out)
                        and decode(get_ram_data(instruction_ram_read_out)) /= program_end
                    then
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
                            program_counter <= get_single_argument(get_ram_data(instruction_ram_read_out));
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

