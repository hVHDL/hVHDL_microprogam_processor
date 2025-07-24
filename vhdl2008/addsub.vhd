library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

    use work.real_to_fixed_pkg.all;

package fixed_dsp_pkg is

    type fixed_dsp_input_array is array (natural range <>) of signed;
    type fixed_dsp_output_array is array (natural range <>) of signed;

    -- constant number_of_pipeline_cycles : integer := g_input_registers + g_output_registers-1;

    type fixed_dsp_record is record
        a : fixed_dsp_input_array;
        b : fixed_dsp_input_array;
        c : fixed_dsp_input_array;
        result : fixed_dsp_output_array;
        shift_register : std_logic_vector;
    end record;

    type fixed_dsp_ref_record is record
        a     : fixed_dsp_input_array;
        b     : fixed_dsp_input_array;
        c     : fixed_dsp_input_array;
        result : fixed_dsp_output_array;
        shift_register    : std_logic_vector;
        pipeline_delay    : natural;
        wordlength        : natural;
    end record;

    function create_fixed_dsp_ref_type (
        a_length      : natural := 36
        ; input_regs  : natural := 2
        ; output_regs : natural := 1)
    return fixed_dsp_ref_record;

end package fixed_dsp_pkg;

package body fixed_dsp_pkg is

    function create_fixed_dsp_ref_type (
        a_length      : natural := 36
        ; input_regs  : natural := 2
        ; output_regs : natural := 1)
        return fixed_dsp_ref_record 
    is
        constant num_ref : signed := to_fixed(0.0, a_length, a_length);
        constant a_ref : fixed_dsp_input_array(0 to input_regs-1) := (0 to input_regs-1 => num_ref);
        constant c_ref : fixed_dsp_input_array(0 to input_regs) := (0 to input_regs => num_ref);
        constant res_ref : fixed_dsp_output_array(0 to output_regs-1) := (0 to output_regs-1 => to_fixed(0.0, a_length*2, a_length));

        constant retval : fixed_dsp_ref_record := (
            a  => a_ref
            ,b => a_ref
            ,c => c_ref
            ,result => res_ref
            ,shift_register => (0 to input_regs+output_regs-1 => '0')
            ,pipeline_delay => input_regs + output_regs
            ,wordlength => a_length);
    begin

        return retval;

    end create_fixed_dsp_ref_type;

    procedure create_fixed_dsp(signal self : inout fixed_dsp_record) is
    begin
        -- fix this
        -- self.result(result'high) <= self.a(self.a'high) * self.b(self.b'high);
        -- self.c(1) <= self.c(0);
        -- self.mpy_res  <= mpy_res2 + shift_left(resize(self.c(1) , mpy_res'length), radix) ;

    end create_fixed_dsp;

end package body fixed_dsp_pkg;
-------------------------------------------------

LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

    use work.multi_port_ram_pkg.all;
    use work.microinstruction_pkg.all;

entity instruction is
    generic(
        arg1_mem      : natural := 0
        ;arg2_mem      : natural := 1
        ;arg3_mem      : natural := 2
        ;radix         : natural := 14
        ;g_read_delays     : natural := 0
        ;g_read_out_delays : natural := 0
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
        ;instr_pipeline           : in instruction_pipeline_array
    );
    use work.real_to_fixed_pkg.all;
end;

architecture add_sub_mpy of instruction is

    constant datawidth : natural := data_read_out(data_read_out'left).data'length;
    signal a, b, c , cbuf : signed(datawidth-1 downto 0);
    signal mpy_res        : signed(2*datawidth-1 downto 0);
    signal mpy_res2       : signed(2*datawidth-1 downto 0);

    signal accumulator : signed(datawidth-1 downto 0) := (others => '0');

begin

    mpy_add_sub : process(clock) is
    begin
        if rising_edge(clock) then
            init_mp_ram_read(data_read_in);
            init_mp_write(ram_write_in);

            ---------------
            if ram_read_is_ready(instruction_ram_read_out) then
                CASE decode(get_ram_data(instruction_ram_read_out)) is
                    WHEN mpy_add 
                        | neg_mpy_add 
                        | neg_mpy_sub 
                        | mpy_sub 
                        | a_add_b_mpy_c 
                        | a_sub_b_mpy_c 
                        | lp_filter 
                        | acc 
                        | get_acc_and_zero 
                        | check_and_saturate_acc 
                        =>

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

            CASE decode(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay+g_read_delays + g_read_out_delays)) is
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

                WHEN acc | get_acc_and_zero =>
                    accumulator <= accumulator + signed(get_ram_data(data_read_out(arg3_mem)));

                WHEN check_and_saturate_acc =>

                    if signed(get_ram_data(data_read_out(arg3_mem))) < 0
                    then
                        if accumulator <= signed(get_ram_data(data_read_out(arg2_mem)))
                        then
                            accumulator <= signed(get_ram_data(data_read_out(arg2_mem)));
                        end if;
                    else
                        if accumulator >= signed(get_ram_data(data_read_out(arg2_mem)))
                        then
                            accumulator <= signed(get_ram_data(data_read_out(arg2_mem)));
                        end if;
                    end if;

                WHEN others => -- do nothing
            end CASE;
            ---------------
            CASE decode(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays)) is
                WHEN mpy_add 
                    | neg_mpy_add   
                    | neg_mpy_sub   
                    | mpy_sub
                    | a_add_b_mpy_c 
                    | a_sub_b_mpy_c 
                    | lp_filter =>

                    write_data_to_ram(ram_write_in 
                    , get_dest(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays))
                    , std_logic_vector(mpy_res(radix+data_read_out(data_read_out'left).data'length-1 downto radix)));

                WHEN get_acc_and_zero =>

                    write_data_to_ram(ram_write_in
                    , get_dest(instr_pipeline(work.dual_port_ram_pkg.read_pipeline_delay + 3 + g_read_delays+ g_read_out_delays))
                    , std_logic_vector(accumulator));

                    accumulator <= (others => '0');

                WHEN others => -- do nothing
            end CASE;
            ---------------

        end if;
    end process mpy_add_sub;

end add_sub_mpy;
----
