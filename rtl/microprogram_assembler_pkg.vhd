------------------------------------------------------------------------
-- microprogram_assembler_pkg : programs written once, as the instructions
-- in order, and laid out for a processor configuration
--
--   schedule(config, code) : each instruction in the first slot where
--       the results it reads are readable, nops in between, and the block
--       padded at its end until all its results are readable, so blocks
--       can follow each other with &
--   repeat(config, count, code) : set_rpt, the scheduled body and a jump
--       back, count rounds ; a round starts when the last one's results
--       are readable
--   place(program, at, code) : code into a program at an address
--   encode_data(entries, config, words) : a data ram's contents from
--       (address, value) pairs, the values reals at the data width and
--       radix ; set_data() writes pairs into existing contents
--
-- and encode(program, width) from microinstruction_pkg makes the ram
-- contents. The configuration's result_latency is the execution unit's,
-- for fixed_mult_add and fixed_mult_acc execution_unit_pkg's
-- fixed_point_result_latency(). It counts the clock the data ram takes
-- the write in, and a read in that clock is a collision between the
-- ram's write and read ports, which gives no defined data on the FPGAs
-- the processor is tested on, so a result is never read in that clock.
--
-- The instructions keep their order. repeat() takes the sequencer's one
-- repeat counter, repeats do not nest.
------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

    use work.microinstruction_pkg.all;
    use work.dual_port_ram_pkg.ram_array;

package microprogram_assembler_pkg is

    type processor_config is record
        instruction_width : natural;
        data_width        : natural;
        radix             : natural;
        -- the instructions after an instruction that cannot read its result
        result_latency    : natural;
    end record;

    function schedule (config : processor_config; code : microprogram) return microprogram;
    function repeat (config : processor_config; count : positive; code : microprogram) return microprogram;
    function place (program : microprogram; at : natural; code : microprogram) return microprogram;

    -- a program ram of size words of nop
    function empty_program (size : natural) return microprogram;

    -- data ram contents
    type data_entry is record
        address : natural;
        value   : real;
    end record;
    type data_list is array (natural range <>) of data_entry;

    -- value * 2**radix rounded, at the data width (up to 60 bits)
    function to_fixed (value : real; config : processor_config) return std_logic_vector;
    function encode_data (entries : data_list; config : processor_config; words : positive) return ram_array;
    function set_data (data : ram_array; entries : data_list; config : processor_config) return ram_array;

    -- the commands' data ram use
    function writes_result (command : t_command) return boolean;
    function reads_arguments (command : t_command) return boolean;
    function uses_accumulator (command : t_command) return boolean;

end package microprogram_assembler_pkg;

package body microprogram_assembler_pkg is

    type natural_array is array (natural range <>) of natural;

    function writes_result (command : t_command) return boolean is
    begin
        case command is
            when mpy_add | mpy_sub | neg_mpy_add | neg_mpy_sub
                | a_add_b_mpy_c | a_sub_b_mpy_c | lp_filter | get_acc_and_zero =>
                return true;
            when others =>
                return false;
        end case;
    end writes_result;

    function reads_arguments (command : t_command) return boolean is
    begin
        case command is
            when mpy_add | mpy_sub | neg_mpy_add | neg_mpy_sub
                | a_add_b_mpy_c | a_sub_b_mpy_c | lp_filter
                | acc | get_acc_and_zero | check_and_saturate_acc | mpy_acc =>
                return true;
            when others =>
                return false;
        end case;
    end reads_arguments;

    function uses_accumulator (command : t_command) return boolean is
    begin
        case command is
            when acc | get_acc_and_zero | check_and_saturate_acc | mpy_acc =>
                return true;
            when others =>
                return false;
        end case;
    end uses_accumulator;

    function empty_program (size : natural) return microprogram is
        variable retval : microprogram(0 to size-1) := (others => mi(nop));
    begin
        return retval;
    end empty_program;

    -- the slot of each instruction of code, and after them the scheduled
    -- length : the slot after the last instruction or, if later, the slot
    -- from which all results are readable
    function schedule_slots (config : processor_config; code : microprogram) return natural_array is
        constant latency : natural := config.result_latency;
        -- the slot from which each data address and the accumulator can be read
        variable ready     : natural_array(0 to 2**address_bits(config.instruction_width)-1) := (others => 0);
        variable acc_ready : natural := 0;
        variable slots     : natural_array(0 to code'length) := (others => 0);
        variable next_slot : natural := 0;
        variable tail      : natural := 0;
        variable slot      : natural;
        variable i         : microinstruction;
    begin
        for k in 0 to code'length-1 loop
            i := code(code'low + k);
            assert i.command /= jump and i.command /= set_rpt
                report "schedule() takes no jump or set_rpt, repeat() makes them" severity failure;
            slot := next_slot;
            if reads_arguments(i.command) then
                slot := maximum(slot, maximum(ready(i.arg1), maximum(ready(i.arg2), ready(i.arg3))));
            end if;
            if uses_accumulator(i.command) then
                slot := maximum(slot, acc_ready);
            end if;
            if i.command = program_end then
                -- ready when the results are in the data ram
                slot := maximum(slot, tail);
            end if;
            if i.command /= nop then
                slots(k)  := slot;
                next_slot := slot + 1;
            end if;
            if writes_result(i.command) then
                ready(i.dest) := slot + latency;
                tail          := maximum(tail, slot + latency);
            end if;
            if i.command = get_acc_and_zero then
                acc_ready := slot + latency;
            end if;
        end loop;
        slots(code'length) := maximum(next_slot, tail);
        return slots;
    end schedule_slots;

    function schedule (config : processor_config; code : microprogram) return microprogram is
        constant slots  : natural_array := schedule_slots(config, code);
        variable retval : microprogram(0 to slots(code'length)-1) := (others => mi(nop));
    begin
        for k in 0 to code'length-1 loop
            if code(code'low + k).command /= nop then
                retval(slots(k)) := code(code'low + k);
            end if;
        end loop;
        return retval;
    end schedule;

    constant delay_slots : natural := 3;

    -- where the jump goes in a scheduled body : a round, from the body's
    -- first slot to the slot after the jump's three delay slots, is at
    -- least the body's length, so its results are readable when the next
    -- round starts ; body instructions can be in the delay slots
    function jump_slot (scheduled : microprogram) return natural is
        variable retval : natural := maximum(scheduled'length - (delay_slots + 1), 0);
    begin
        while retval < scheduled'length and scheduled(scheduled'low + retval).command /= nop loop
            retval := retval + 1;
        end loop;
        return retval;
    end jump_slot;

    function repeat (config : processor_config; count : positive; code : microprogram) return microprogram is
        constant scheduled : microprogram := schedule(config, code);
        constant jump_at   : natural := jump_slot(scheduled);
        -- set_rpt, the body and the jump with its delay slots
        variable retval : microprogram(0 to maximum(scheduled'length, jump_at + delay_slots + 1)) := (others => mi(nop));
    begin
        retval(0) := mi(set_rpt, count - 1);
        for k in 0 to scheduled'length-1 loop
            retval(1 + k) := scheduled(scheduled'low + k);
        end loop;
        retval(1 + jump_at) := mi(jump, jump_at); -- back to the body's first slot
        retval(1 + jump_at).relative := true;
        return retval;
    end repeat;

    function place (program : microprogram; at : natural; code : microprogram) return microprogram is
        variable retval : microprogram(program'range) := program;
    begin
        assert at + code'length - 1 <= program'high
            report "code at " & integer'image(at) & " does not fit the program" severity failure;
        for k in 0 to code'length-1 loop
            if code(code'low + k).command /= nop then
                assert retval(at + k).command = nop
                    report "code at " & integer'image(at) & " overlaps an instruction at "
                        & integer'image(at + k) severity failure;
                retval(at + k) := code(code'low + k);
            end if;
        end loop;
        return retval;
    end place;

    function to_fixed (value : real; config : processor_config) return std_logic_vector is
        constant w      : natural := config.data_width;
        constant scaled : real := round(value * 2.0**config.radix);
        -- in two parts, an integer has only 32 bits
        constant high   : real := floor(scaled / 2.0**30);
        constant low    : real := scaled - high * 2.0**30;
    begin
        assert w <= 60 report "to_fixed() takes data up to 60 bits" severity failure;
        assert scaled >= -(2.0**(w-1)) and scaled < 2.0**(w-1)
            report real'image(value) & " does not fit " & integer'image(w) & " bits at radix "
                & integer'image(config.radix) severity failure;
        return std_logic_vector(shift_left(resize(to_signed(integer(high), 34), w), 30)
            + resize(to_signed(integer(low), 32), w));
    end to_fixed;

    function set_data (data : ram_array; entries : data_list; config : processor_config) return ram_array is
        variable retval : ram_array(data'range)(config.data_width-1 downto 0) := data;
    begin
        for k in entries'range loop
            assert entries(k).address >= data'low and entries(k).address <= data'high
                report "data at " & integer'image(entries(k).address) & " is outside the data ram"
                severity failure;
            for j in entries'low to k-1 loop
                assert entries(j).address /= entries(k).address
                    report "data at " & integer'image(entries(k).address) & " is given twice"
                    severity failure;
            end loop;
            retval(entries(k).address) := to_fixed(entries(k).value, config);
        end loop;
        return retval;
    end set_data;

    function encode_data (entries : data_list; config : processor_config; words : positive) return ram_array is
        constant zeros : ram_array(0 to words-1)(config.data_width-1 downto 0) := (others => (others => '0'));
    begin
        return set_data(zeros, entries, config);
    end encode_data;

end package body microprogram_assembler_pkg;
