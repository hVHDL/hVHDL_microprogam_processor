LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;

entity instruction is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
        ;arg1_mem      : natural := 1
        ;arg2_mem      : natural := 2
        ;arg3_mem      : natural := 3
        ;inst_mem      : natural := 0
        ;radix         : natural := 14
        ------ instruction encodings -------
        ;g_mpy_add       : natural := 0
        ;g_mpy_sub       : natural := 1
        ;g_neg_mpy_add   : natural := 2
        ;g_neg_mpy_sub   : natural := 3
        ;g_a_add_b_mpy_c : natural := 4
        ;g_a_sub_b_mpy_c : natural := 5
        ;g_lp_filter     : natural := 6
       );
    port(
        clock : in std_logic
        ;instruction_ram_read_out : in ram_read_out_record
        ;data_read_in             : out ram_read_in_array
        ;data_read_out            : in ram_read_out_array
        ;ram_write_in             : out ram_write_in_record
        ;instr_pipeline           : in microinstruction_pkg.instruction_pipeline_array
    );
    use microinstruction_pkg.all;
    use work.real_to_fixed_pkg.all;
end;

architecture add_sub_mpy of instruction is

    signal a, b, c , cbuf : signed(data_bit_width-1 downto 0);
    signal mpy_res        : signed(2*data_bit_width-1 downto 0);
    signal mpy_res2       : signed(2*data_bit_width-1 downto 0);

begin

    mpy_add_sub : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(data_read_in);
            init_mp_write(ram_write_in);

            ---------------
            if ram_read_is_ready(instruction_ram_read_out) then
                CASE decode(get_ram_data(instruction_ram_read_out)) is
                    WHEN mpy_add | neg_mpy_add | neg_mpy_sub | mpy_sub | a_add_b_mpy_c | a_sub_b_mpy_c | lp_filter =>

                        request_data_from_ram(data_read_in(arg1_mem)
                            , get_arg1(get_ram_data(instruction_ram_read_out)));

                        request_data_from_ram(data_read_in(arg2_mem)
                            , get_arg2(get_ram_data(instruction_ram_read_out)));

                        request_data_from_ram(data_read_in(arg3_mem)
                            , get_arg3(get_ram_data(instruction_ram_read_out)));

                    WHEN others => -- do nothing
                end CASE;
            end if;

            ---------------
            mpy_res2 <= a * b;
            cbuf     <= c;
            mpy_res  <= mpy_res2 + shift_left(resize(cbuf , mpy_res'length), radix) ;
            ---------------

            CASE decode(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay)) is
                WHEN mpy_add =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(data_read_out(arg3_mem)));

                WHEN neg_mpy_add =>
                    a <= signed( not get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed(get_ram_data(data_read_out(arg3_mem)));

                WHEN neg_mpy_sub =>
                    a <= signed( not get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed( not get_ram_data(data_read_out(arg3_mem)));

                WHEN mpy_sub =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)));
                    b <= signed(get_ram_data(data_read_out(arg2_mem)));
                    c <= signed( not get_ram_data(data_read_out(arg3_mem)));

                WHEN a_add_b_mpy_c =>
                    a <=   signed(get_ram_data(data_read_out(arg1_mem)))
                         + signed(get_ram_data(data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN a_sub_b_mpy_c =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)))
                         + signed( not get_ram_data(data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(data_read_out(arg3_mem)));
                    c <= (others => '0');

                WHEN lp_filter =>
                    a <= signed(get_ram_data(data_read_out(arg1_mem)))
                         + signed( not get_ram_data(data_read_out(arg2_mem)));
                    b <= signed(get_ram_data(data_read_out(arg3_mem)));
                    c <= signed(get_ram_data(data_read_out(arg2_mem)));

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3)) is
                WHEN mpy_add | neg_mpy_add | neg_mpy_sub | mpy_sub | a_add_b_mpy_c |a_sub_b_mpy_c | lp_filter =>
                    write_data_to_ram(ram_write_in 
                    , get_dest(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3))
                    , std_logic_vector(mpy_res(radix+data_read_out(data_read_out'left).data'length-1 downto radix)));
                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
----
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;

entity microprogram_sequencer is
    generic(
        package microinstruction_pkg is new work.generic_microinstruction_pkg generic map (<>)
      );
    port(
        clock : in std_logic

        ;instruction_ram_read_in  : out ram_read_in_record
        ;instruction_ram_read_out : in ram_read_out_record

        ;processor_enabled   : out boolean
        ;instr_pipeline      : out microinstruction_pkg.instruction_pipeline_array
        ;processor_requested : in boolean := true
        ;start_address       : in natural := 0
    );
    use microinstruction_pkg.all;
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
            for i in instr_pipeline'high downto 1 loop
                instr_pipeline(i) <= instr_pipeline(i-1);
            end loop;
            instr_pipeline(0) <= op(nop);
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
                            instr_pipeline(0) <= get_ram_data(instruction_ram_read_out);
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

LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

entity microprogram_sequencer_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of microprogram_sequencer_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1500;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    use work.real_to_fixed_pkg.all;

    package microinstruction_pkg is new work.generic_microinstruction_pkg 
        generic map(g_number_of_pipeline_stages => 6);
        use microinstruction_pkg.all;

    use work.multi_port_ram_pkg.all;
    constant datawidth : natural := 20;
    constant ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 5, datawidth => datawidth);
    signal ram_read_in  : ref_subtype.ram_read_in'subtype;
    signal ram_read_out : ref_subtype.ram_read_out'subtype;
    signal ram_write_in : ref_subtype.ram_write_in'subtype;

    constant instr_ref_subtype : subtype_ref_record := create_ref_subtypes(readports => 1, datawidth => 32, addresswidth => 8);
    signal instr_ram_read_in  : instr_ref_subtype.ram_read_in'subtype;
    signal instr_ram_read_out : instr_ref_subtype.ram_read_out'subtype;
    signal instr_ram_write_in : instr_ref_subtype.ram_write_in'subtype;

    constant used_radix : natural := 14;

    constant test_data : work.dual_port_ram_pkg.ram_array(0 to ref_subtype.address_high)(ref_subtype.data'range) := (
          101 => to_fixed(1.5  , datawidth , used_radix)
        , 102 => to_fixed(0.5  , datawidth , used_radix)
        , 103 => to_fixed(-1.5 , datawidth , used_radix)
        , 104 => to_fixed(-0.5 , datawidth , used_radix)
        , 105 => to_fixed(-1.0 , datawidth , used_radix)

        , others => (others => '0'));

    constant test_program : work.dual_port_ram_pkg.ram_array(0 to instr_ref_subtype.address_high)(instr_ref_subtype.data'range) := (
        6   => sub( 96, 101,101)

        , 7  => sub( 100 , 101 , 102)
        , 8  => sub( 99  , 102 , 101)
        , 9  => add( 98  , 103 , 104)
        , 10 => add( 97  , 104 , 103)
        , 11 => op(mpy_add , 96  , 101 , 104  , 105)
        , 12 => op(mpy_add , 95  , 102 , 104  , 102)

        , others => op(program_end));

    signal command        : t_command                  := (program_end);
    signal instr_pipeline : instruction_pipeline_array := (others => op(nop));

    -- signal pim_ram_write     : ram_write_in_record;
    -- signal add_sub_ram_write : ram_write_in_record;

    signal processor_enabled : boolean := true;
    signal processor_requested : boolean := false;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;

------------------------------------------------------------------------
------------------------------------------------------------------------
    stimulus : process(simulator_clock)
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
        end if; -- rising_edge
    end process stimulus;	
----------------------------------------------------------
    u_microprogram_sequencer : entity work.microprogram_sequencer
    generic map(microinstruction_pkg)
    port map(simulator_clock 
    , instr_ram_read_in(0) 
    , instr_ram_read_out(0) 
    , processor_enabled   => processor_enabled
    , instr_pipeline      => instr_pipeline
    , processor_requested => processor_requested
    , start_address       => 0);
-- ----------------------------------------------------------
--     add_sub_mpy : entity work.instruction
--     generic map(microinstruction_pkg, mp_ram_pkg, radix => used_radix)
--     port map(simulator_clock , sub_read_in , ram_read_out , add_sub_ram_write , instr_pipeline);
------------------------------------------------------------------------
------------------------------------------------------------------------
    -- ram_read_in  <= pc_read_in   and sub_read_in;
    -- ram_write_in <= pim_ram_write and add_sub_ram_write;

    u_instruction_ram : entity work.multi_port_ram
    generic map(test_program)
    port map(
        clock => simulator_clock
        ,ram_read_in  => instr_ram_read_in
        ,ram_read_out => instr_ram_read_out
        ,ram_write_in => instr_ram_write_in);

    u_dataram : entity work.multi_port_ram
    generic map(test_data)
    port map(
        clock => simulator_clock
        ,ram_read_in  => ram_read_in
        ,ram_read_out => ram_read_out
        ,ram_write_in => ram_write_in);
------------------------------------------------------------------------
end vunit_simulation;
