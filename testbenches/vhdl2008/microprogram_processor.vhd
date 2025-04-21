LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

entity microprogram_processor is
    generic(
            package processor_microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
            ;package processor_mp_ram_pkg is new work.generic_multi_port_ram_pkg generic map (<>)
            ;g_used_radix : natural
            ;g_program : processor_mp_ram_pkg.ram_array
           );
    port(
        clock : in std_logic
        ;calculate     : in boolean := false
        ;start_address : in natural := 0
        ;output1       : out signed(31 downto 0)
        ;o1_ready      : out boolean
    );
end microprogram_processor;

architecture rtl of microprogram_processor is

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => 6);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.ram_bit_width
        ,g_ram_depth_pow2 => 10);
        use mp_ram_pkg.all;

    signal ram_read_in : ram_read_in_array(0 to 4);
    signal pc_read_in  : ram_read_in_array(0 to 4);
    signal sub_read_in : ram_read_in_array(0 to 4);

    signal ram_write_in      : ram_write_in_record;
    signal pim_ram_write     : ram_write_in_record;
    signal add_sub_ram_write : ram_write_in_record;

    signal ram_read_out : ram_read_out_array(ram_read_in'range);

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
            o1_ready <= false;
            if write_requested(ram_write_in) then
                if get_address(ram_write_in) >= 95
                    and get_address(ram_write_in) <= 100 
                then
                    output1 <= signed(get_data(ram_write_in));
                    o1_ready <= true;
                end if;
            end if;
        end if;
    end process;

----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(microinstruction_pkg, mp_ram_pkg)
    port map(clock , pc_read_in , ram_read_out , pim_ram_write , processor_enabled, instr_pipeline
    , calculate => calculate
    , start_address =>start_address);
----------------------------------------------------------
    add_sub_mpy : entity work.instruction
    generic map(microinstruction_pkg, mp_ram_pkg, radix => used_radix)
    port map(clock , sub_read_in , ram_read_out , add_sub_ram_write , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
    ram_read_in  <= pc_read_in   and sub_read_in;
    ram_write_in <= pim_ram_write and add_sub_ram_write;

    u_mpram : entity work.multi_port_ram
    generic map(mp_ram_pkg, test_program)
    port map(
        clock => clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);
---------------------------------------
end rtl;
