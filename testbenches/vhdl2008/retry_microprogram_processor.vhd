library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package microprogram_processor_pkg is

    type microprogram_processor_in_record is record
        processor_requested  : boolean;
        start_address        : natural;
    end record;

    type microprogram_processor_out_record is record
        is_busy : boolean;
    end record;

    procedure init_mproc (signal self_in : out microprogram_processor_in_record);
    procedure calculate (signal self_in : out microprogram_processor_in_record; start_address : in natural);

end package microprogram_processor_pkg;

------------------

package body microprogram_processor_pkg is

    procedure init_mproc (signal self_in : out microprogram_processor_in_record) is
    begin
        self_in.processor_requested <= false;
    end init_mproc;

    procedure calculate (signal self_in : out microprogram_processor_in_record; start_address : in natural) is
    begin
        self_in.processor_requested <= true;
        self_in.start_address <= start_address;
    end calculate;


end package body microprogram_processor_pkg;

--------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

entity microprogram_processor is
    generic(
            g_instruction_bit_width : natural := 32
            ;g_data_bit_width : natural := 32
            ;g_number_of_pipeline_stages : natural := 10
            ;g_used_radix : natural
            ;g_program    : work.dual_port_ram_pkg.ram_array
            ;g_data       : work.dual_port_ram_pkg.ram_array
           );
    port(
        clock        : in std_logic
        ;mproc_in    : in work.microprogram_processor_pkg.microprogram_processor_in_record
        ;mproc_out   : out work.microprogram_processor_pkg.microprogram_processor_out_record
        ;mc_read_in  : out ram_read_in_array
        ;mc_read_out : in ram_read_out_array
        ;mc_output   : out ram_write_in_record
    );
end microprogram_processor;

architecture rtl of microprogram_processor is

    constant ref_subtype       : subtype_ref_record := create_ref_subtypes(readports => 3 , datawidth => g_data_bit_width);
    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 1 , datawidth => 32   , addresswidth => 10);

    signal instr_ram_read_in   : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out  : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in  : instr_ref_subtype.ram_write_in'subtype;

    signal ram_read_in : ref_subtype.ram_read_in'subtype;
    signal pc_read_in  : ref_subtype.ram_read_in'subtype;
    signal sub_read_in : ref_subtype.ram_read_in'subtype;

    signal ram_write_in      : ref_subtype.ram_write_in'subtype;
    signal add_sub_ram_write : ref_subtype.ram_write_in'subtype;

    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal data_ram_read_out : ref_subtype.ram_read_out'subtype;

    use work.real_to_fixed_pkg.all;

    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

begin

----------------------------------------------------------
    process(clock) is
    begin
        if rising_edge(clock)
        then
            mc_output.address <= ram_write_in.address;
            mc_output.data <= ram_write_in.data;
            mc_output.write_requested <= ram_write_in.write_requested;
        end if;
    end process;
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    port map(clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => mproc_out.is_busy
    , instr_pipeline      => instr_pipeline
    , processor_requested => mproc_in.processor_requested
    , start_address       => mproc_in.start_address);
----------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(radix => g_used_radix)
    port map(clock 
    , instr_ram_read_out(0) 
    , sub_read_in
    , data_ram_read_out 
    , add_sub_ram_write 
    , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
----
    combine_ram_buses : process(all) is
    begin
        if rising_edge(clock)
        then
            mc_read_in   <= combine((0 => sub_read_in) , ref_subtype.address , no_map_range_low => 0, no_map_range_hi => 119);
            ram_read_in  <= combine((0 => sub_read_in) , ref_subtype.address , no_map_range_low => 119, no_map_range_hi => 127);
            ram_write_in <= combine((0 => add_sub_ram_write));

            for i in ram_read_out'range loop
                if mc_read_out(i).data_is_ready then
                    data_ram_read_out(i).data          <= mc_read_out(i).data;
                    data_ram_read_out(i).data_is_ready <= mc_read_out(i).data_is_ready;
                else
                    data_ram_read_out(i) <= ram_read_out(i);
                end if;
            end loop;
        end if;
    end process combine_ram_buses;
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
end rtl;
