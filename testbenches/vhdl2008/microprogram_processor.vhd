LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

entity microprogram_processor is
    generic(
            package processor_microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
            ;package processor_mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
            ;g_used_radix : natural
            ;g_program : processor_mp_ram_pkg.ram_array
            ;g_data : processor_mp_ram_pkg.ram_array
           );
    port(
        clock          : in std_logic
        ;calculate     : in boolean := false
        ;start_address : in natural := 0
        ;mc_read_in    : out processor_mp_ram_pkg.ram_read_in_array(0 to 3)
        ;mc_read_out   : in processor_mp_ram_pkg.ram_read_out_array(0 to 3)
        ;mc_output     : out processor_mp_ram_pkg.ram_write_in_record
    );
end microprogram_processor;

architecture rtl of microprogram_processor is

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => processor_microinstruction_pkg.number_of_pipeline_stages);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.ram_bit_width
        ,g_ram_depth_pow2 => 10);
        use mp_ram_pkg.all;

    signal ram_read_in : ram_read_in_array(0 to 3);
    signal pc_read_in  : ram_read_in_array(0 to 3);
    signal sub_read_in : ram_read_in_array(0 to 3);
    signal ext_read_in : ram_read_in_array(0 to 3);

    signal ram_write_in      : ram_write_in_record;
    signal pim_ram_write     : ram_write_in_record;
    signal add_sub_ram_write : ram_write_in_record;

    signal ram_write_in1      : ram_write_in_record;

    signal ram_read_out : ram_read_out_array(ram_read_in'range);
    signal data_ram_read_out : ram_read_out_array(ram_read_in'range);

    constant used_radix : natural := g_used_radix;

    use work.real_to_fixed_pkg.all;

    function pimpom(a : processor_mp_ram_pkg.ram_array) return mp_ram_pkg.ram_array is
        variable retval : mp_ram_pkg.ram_array;
    begin
        for i in a'range loop
            retval(i) := a(i);
        end loop;

        return retval;
    end pimpom;

    constant test_program : mp_ram_pkg.ram_array := pimpom(g_program);

    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    --
    signal processor_enabled : boolean := false;
    --

begin

------------------------------------------------------------------------
    debug : process(all) is
    begin
        if ram_read_is_ready(ram_read_out(0)) then
            command <= decode(get_ram_data(ram_read_out(0)));
        end if;
    end process debug;
------------------------------------------------------------------------
    process(clock) is
    begin
        if rising_edge(clock)
        then
            processor_mp_ram_pkg.init_mp_write(mc_output);
            if write_requested(ram_write_in) then
                if get_address(ram_write_in) >= 50
                    and get_address(ram_write_in) <= 59 
                then
                    processor_mp_ram_pkg.write_data_to_ram(mc_output,get_address(ram_write_in), get_data(ram_write_in));
                end if;
            end if;
        end if;
    end process;
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(microinstruction_pkg, mp_ram_pkg)
    port map(clock , pc_read_in , data_ram_read_out , pim_ram_write , processor_enabled, instr_pipeline
    , calculate
    , start_address);
----------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(microinstruction_pkg , mp_ram_pkg , radix => used_radix)
    port map(clock , sub_read_in , data_ram_read_out , add_sub_ram_write , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
----
    combine_ram_buses : process(all) is
    begin

        for i in ext_read_in'range loop
            mc_read_in(i).address        <= ext_read_in(i).address;
            mc_read_in(i).read_requested <= ext_read_in(i).read_requested;
        end loop;

        for i in data_ram_read_out'range loop
            if mc_read_out(i).data_is_ready then
                data_ram_read_out(i).data          <= mc_read_out(i).data;
                data_ram_read_out(i).data_is_ready <= mc_read_out(i).data_is_ready;
            else
                data_ram_read_out(i) <= ram_read_out(i);
            end if;
        end loop;
        data_ram_read_out(0) <= ram_read_out(0);

        ext_read_in  <= combine((0 => pc_read_in    , 1 => sub_read_in)         , no_map_range_hi => 119);
        ram_read_in  <= combine((0 => pc_read_in    , 1 => sub_read_in)         , no_map_range_low => 119);
        ram_write_in <= combine((0 => pim_ram_write , 1 => add_sub_ram_write));
    end process combine_ram_buses;
----
    u_program_ram : entity work.multi_port_ram
    generic map(mp_ram_pkg, test_program)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in(0 to 0)
        ,ram_read_out => ram_read_out(0 to 0)
        ,ram_write_in => ram_write_in1);
----
    u_data_ram : entity work.multi_port_ram
    generic map(mp_ram_pkg, g_data)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in(1 to ram_read_in'high)
        ,ram_read_out => ram_read_out(1 to ram_read_in'high)
        ,ram_write_in => ram_write_in);
---------------------------------------
end rtl;
