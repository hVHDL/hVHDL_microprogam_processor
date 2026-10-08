------------------------------------------------------------------------
-- microprogram_assembler_pkg : programs written once, as the instructions
-- in order, and laid out for a processor configuration
--
--   schedule(config, code) : each instruction in the first slot where
--       the results it reads are readable and its write does not meet
--       another write, nops in between, and the block padded at its end
--       until all its results are readable, so blocks can follow each
--       other with &. ext (the math unit) has its own result latency ;
--       the data ram has one write port, two units cannot write in one
--       clock
--   repeat(config, count, code) : set_rpt, the scheduled body and a jump
--       back, count rounds ; a round starts when the last one's results
--       are readable
--   place(program, at, code) : code into a program at an address, failing
--       where it overlaps code placed before, nops included
--   encode_data(entries, config, words) : a data ram's contents from
--       (address, value) pairs, the values reals at the data width and
--       radix ; set_data() writes pairs into existing contents
--
-- and encode(program, width) from microinstruction_pkg makes the ram
-- contents. The configuration's result_latency is the execution unit's,
-- for fixed_mult_add execution_unit_pkg's
-- fixed_point_result_latency(). It counts the clock the data ram takes
-- the write in, and a read in that clock is a collision between the
-- ram's write and read ports, which gives no defined data on the FPGAs
-- the processor is tested on, so a result is never read in that clock.
-- With microprogram_core's g_data_forwarding the write goes to such reads
-- and the latency is forwarded clocks shorter : schedule() and repeat()
-- end their code that much after the last result is readable, so a
-- program_end after them still marks the results as in the data ram.
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
        -- the instructions after a jump that run before it is taken,
        -- microprogram_interface_pkg's jump_delay_slots()
        delay_slots       : natural;
        -- the math unit's result latency, for ext, execution_unit_pkg's
        -- fixed_math_result_latency() ; 0 without a math unit
        math_latency      : natural;
        -- the clocks data forwarding takes off the latencies,
        -- execution_unit_pkg's forwarded_clocks() : program_end waits them
        -- too, its ready marking the results as in the data ram
        forwarded         : natural;
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
                | a_add_b_mpy_c | a_sub_b_mpy_c | lp_filter | get_acc_and_zero | ext =>
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
                | acc | get_acc_and_zero | check_and_saturate_acc | mpy_acc | ext =>
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
    function latency_of (config : processor_config; command : t_command) return natural is
    begin
        if command = ext then
            assert config.math_latency > 0
                report "ext in a program for a processor_config without a math unit" severity failure;
            return config.math_latency;
        end if;
        return config.result_latency;
    end latency_of;

    type boolean_array is array (natural range <>) of boolean;

    -- the slot of each instruction, and after them the code's length :
    -- to the last result readable, or with landed the results in the
    -- data ram, config.forwarded later
    function schedule_slots (config : processor_config; code : microprogram; landed : boolean := true) return natural_array is
        constant max_latency : natural := maximum(config.result_latency, config.math_latency);
        -- the slot from which each data address and the accumulator can be read
        variable ready     : natural_array(0 to 2**address_bits(config.instruction_width)-1) := (others => 0);
        -- the slots the data ram's write port is taken in
        -- each instruction waits at most a latency and a slot per earlier write
        variable write_taken : boolean_array(0 to (code'length + 1) * (max_latency + 2)) := (others => false);
        variable latency   : natural;
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
            slot    := next_slot;
            latency := latency_of(config, i.command);
            if reads_arguments(i.command) then
                slot := maximum(slot, ready(i.arg1));
                -- ext's arg3 is its function, not an address, and all
                -- but its division read arg1 only
                if not (i.command = ext and i.arg3 /= ext_div) then
                    slot := maximum(slot, ready(i.arg2));
                end if;
                if i.command /= ext then
                    slot := maximum(slot, ready(i.arg3));
                end if;
            end if;
            if uses_accumulator(i.command) then
                slot := maximum(slot, acc_ready);
            end if;
            if i.command = program_end then
                -- ready when the results are in the data ram, forwarded
                -- clocks after they are readable
                slot := maximum(slot, tail + config.forwarded);
            end if;
            if writes_result(i.command) then
                while write_taken(slot + latency) loop
                    slot := slot + 1;
                end loop;
                write_taken(slot + latency) := true;
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
        if landed and tail > 0 then
            slots(code'length) := maximum(next_slot, tail + config.forwarded);
        end if;
        return slots;
    end schedule_slots;

    -- the code at its slots, nops between : with landed its results are
    -- in the data ram at its end, a loop body ends when they are readable
    function schedule_code (config : processor_config; code : microprogram; landed : boolean) return microprogram is
        constant slots  : natural_array := schedule_slots(config, code, landed);
        variable retval : microprogram(0 to slots(code'length)-1) := (others => mi(nop));
    begin
        for k in 0 to code'length-1 loop
            if code(code'low + k).command /= nop then
                retval(slots(k)) := code(code'low + k);
            end if;
        end loop;
        return retval;
    end schedule_code;

    function schedule (config : processor_config; code : microprogram) return microprogram is
    begin
        return schedule_code(config, code, landed => true);
    end schedule;

    -- where the jump goes in a scheduled body : a round, from the body's
    -- first slot to the slot after the jump's delay slots, is at
    -- least the body's length, so its results are readable when the next
    -- round starts ; body instructions can be in the delay slots
    function jump_slot (scheduled : microprogram; delay_slots : natural) return natural is
        variable retval : natural := maximum(scheduled'length - (delay_slots + 1), 0);
    begin
        while retval < scheduled'length and scheduled(scheduled'low + retval).command /= nop loop
            retval := retval + 1;
        end loop;
        return retval;
    end jump_slot;

    function repeat (config : processor_config; count : positive; code : microprogram) return microprogram is
        -- each round reads the last one's results when they are readable
        constant scheduled : microprogram := schedule_code(config, code, landed => false);
        constant jump_at   : natural := jump_slot(scheduled, config.delay_slots);
        -- set_rpt, the body and the jump with its delay slots, and the
        -- forwarded clocks after the last round : a program_end after the
        -- loop marks its results as in the data ram
        variable retval : microprogram(0 to maximum(scheduled'length, jump_at + config.delay_slots + 1) + config.forwarded)
            := (others => mi(nop));
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
        -- the code's whole span, its nops too : a program_end of earlier
        -- code inside it would end this one
        for k in 0 to code'length-1 loop
            assert not retval(at + k).placed and retval(at + k).command = nop
                report "code at " & integer'image(at) & " overlaps code placed before, at "
                    & integer'image(at + k) severity failure;
            retval(at + k)        := code(code'low + k);
            retval(at + k).placed := true;
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
