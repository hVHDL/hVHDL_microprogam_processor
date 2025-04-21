LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

entity microprogram_sequencer is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
        ;package mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
        ;inst_mem : natural := 0
       );
    port(
        clock : in std_logic
        ;ram_read_in  : out mp_ram_pkg.ram_read_in_array
        ;ram_read_out : in mp_ram_pkg.ram_read_out_array
        ;ram_write_in : out mp_ram_pkg.ram_write_in_record
        ;processor_enabled : out boolean
        ;instr_pipeline : out microinstruction_pkg.instruction_pipeline_array
        ;calculate : in boolean := true
        ;start_address : in natural := 0
    );
    use microinstruction_pkg.all;
    use mp_ram_pkg.all;
    use work.real_to_fixed_pkg.all;
end;

architecture rtl of microprogram_sequencer is

    signal program_counter : natural range 0 to 1023 := 0;
    signal rpt_counter     : natural range 0 to 15   := 0;


begin

    make_program_counter : process(clock)

        -- impure function get_pc(pc : natural) return natural is
        --     variable retval : natural := pc;
        -- begin
        --     if processor_enabled
        --     then
        --         retval := retval + 1;
        --     return retval;
        -- end function;
    begin
        if rising_edge(clock) then
            init_mp_ram_read(ram_read_in);
            init_mp_write(ram_write_in);

            if processor_enabled
            then
                program_counter <= program_counter + 1;
                request_data_from_ram(ram_read_in(inst_mem), program_counter);
            else
                if calculate then
                    program_counter   <= start_address;
                    processor_enabled <= true;
                end if;
            end if;
        -----
            for i in instr_pipeline'high downto 1 loop
                instr_pipeline(i) <= instr_pipeline(i-1);
            end loop;
            instr_pipeline(0) <= op(nop);

            if ram_read_is_ready(ram_read_out(0))
            then
                if processor_enabled and decode(get_ram_data(ram_read_out(0))) /= program_end
                then
                    instr_pipeline(0) <= get_ram_data(ram_read_out(0));
                else
                    processor_enabled <= false;
                end if;
            end if;

            ------------ jump instruction ----------------
            if ram_read_is_ready(ram_read_out(0)) and processor_enabled 
            then
                CASE decode(get_ram_data(ram_read_out(0))) is
                    when jump =>
                        if rpt_counter > 0 then
                            rpt_counter <= rpt_counter - 1;
                            program_counter <= get_single_argument(get_ram_data(ram_read_out(0)));
                        end if;
                    WHEN set_rpt =>
                        rpt_counter <= get_single_argument(get_ram_data(ram_read_out(0)));
                    when others => --do nothing
                end CASE;
            end if;
            ----------------------------------------------

        end if; -- rising_edge
    end process make_program_counter;	
------------------------------------------------------------------------
end rtl;
