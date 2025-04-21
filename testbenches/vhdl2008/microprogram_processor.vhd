LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 

entity microprogram_processor is
    generic(g_used_radix : natural);
    port(
        clock : in std_logic
        ;calculate : in boolean := false
        ;start_address : in natural := 0
        ;output1 : out signed(31 downto 0)
        ;o1_ready : out boolean
    );
end microprogram_processor;

architecture rtl of microprogram_processor is

    use work.real_to_fixed_pkg.all;

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => 6);
        use microinstruction_pkg.all;

    package mp_ram_pkg is new work.generic_multi_port_ram_pkg 
        generic map(
        g_ram_bit_width   => microinstruction_pkg.ram_bit_width
        ,g_ram_depth_pow2 => 10);

    use mp_ram_pkg.all;

    signal ram_read_in  : ram_read_in_array(0 to 4);

    signal pc_read_in  : ram_read_in_array(0 to 4);
    signal sub_read_in  : ram_read_in_array(0 to 4);

    signal ram_read_out : ram_read_out_array(ram_read_in'range);
    signal ram_write_in : ram_write_in_record;

    constant used_radix : natural := g_used_radix;

    constant test_program : ram_array :=(
        6   => op(sub, 96, 101,101)

        , 7  => op(sub     , 100 , 101 , 102)
        , 8  => op(sub     , 99  , 102 , 101)
        , 9  => op(add     , 98  , 103 , 104)
        , 10 => op(add     , 97  , 104 , 103)
        , 11 => op(mpy_add , 96  , 101 , 104  , 105)
        , 12 => op(mpy_add , 95  , 102 , 104  , 102)
        , 13 => op(program_end)

        , 101 => to_fixed(1.5  , 32 , used_radix)
        , 102 => to_fixed(0.5  , 32 , used_radix)
        , 103 => to_fixed(-1.5 , 32 , used_radix)
        , 104 => to_fixed(-0.5 , 32 , used_radix)
        , 105 => to_fixed(-1.0 , 32 , used_radix)

        , others => op(nop));


    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    signal pim_ram_write     : ram_write_in_record;
    signal add_sub_ram_write : ram_write_in_record;
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
    port map(clock , pc_read_in , ram_read_out , pim_ram_write , processor_enabled, instr_pipeline, calculate);
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

end rtl;
---------------------------------------
