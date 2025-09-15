
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;
    use work.instruction_pkg.all;

entity microprogram_controller is
    generic(
            g_number_of_pipeline_stages : natural := 11
            ;g_addresswidth             : natural := 10
            ;g_data_bit_width           : natural := 32
            ;g_program                  : work.dual_port_ram_pkg.ram_array
            ;g_data                     : work.dual_port_ram_pkg.ram_array
            ;g_idle_ram_write           : ram_write_in_record := init_write_in(g_addresswidth, g_data_bit_width)
           );
    port(
        clock        : in std_logic
        ;mproc_in    : in work.microprogram_processor_pkg.microprogram_processor_in_record
        ;mproc_out   : out work.microprogram_processor_pkg.microprogram_processor_out_record
        ;mc_output   : out ram_write_in_record
        ;mc_write_in : in ram_write_in_record := g_idle_ram_write
        ------ instruction entity connection
        ;instruction_in  : out instruction_in_record
        ;instruction_out : in instruction_out_record
    );
end microprogram_controller;

architecture rtl of microprogram_controller is

    constant number_of_dataports : natural := instruction_in.data_read_out'length;
    constant datawidth           : natural := instruction_in.data_read_out(instruction_in.data_read_out'left).data'length;
    constant instruction_width   : natural := instruction_in.instr_ram_read_out(instruction_in.instr_ram_read_out'left).data'length;
    constant pipeline_high       : natural := instruction_in.instr_pipeline'high;

    constant ref_subtype       : subtype_ref_record := create_ref_subtypes(readports => number_of_dataports , datawidth => datawidth);
    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 1 , datawidth => instruction_width   , addresswidth => 10);

    signal instr_ram_read_in   : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out  : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in  : instr_ref_subtype.ram_write_in'subtype;

    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    signal data_ram_read_out : ref_subtype.ram_read_out'subtype;

    signal instr_pipeline : instruction_pipeline_array(0 to pipeline_high) := (0 to pipeline_high => op(nop));

    signal write_buffer : mc_write_in'subtype := g_idle_ram_write;

begin

----------------------------------------------------------
    instruction_in <= (data_ram_read_out, instr_ram_read_out, instr_pipeline);
    mc_output      <= ram_write_in;
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    port map(clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => mproc_out.is_busy
    , instr_pipeline      => instr_pipeline
    , processor_requested => mproc_in.processor_requested
    , start_address       => mproc_in.start_address
    , is_ready            => mproc_out.is_ready);
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
        ,ram_read_in  => instruction_out.data_read_in
        ,ram_read_out => data_ram_read_out
        ,ram_write_in => ram_write_in);
------------------------------------------------------------------------
------------------------------------------------------------------------
    buffer_writes : process(clock) is
    begin
        if rising_edge(clock) 
        then
            if write_requested(mc_write_in) then
                if not write_requested(instruction_out.ram_write_in)
                then
                    write_buffer <= mc_write_in;
                end if;
            end if;
        end if;
    end process;
------------------------------------------------------------------------
    combine_ram_buses : process(all) is
    begin
        -- if rising_edge(clock)
        -- then
            ram_write_in <= combine((0 => instruction_out.ram_write_in));

            if not write_requested(instruction_out.ram_write_in)
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
