library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

package testprogram_pkg is

    type t_command is (add, sub, mpy, div, nop);
    type command_array is array (t_command range t_command'left to t_command'right) of integer;

    subtype comm is std_logic_vector(15 downto 13);
    subtype dest is std_logic_vector(12 downto 10);
    subtype arg1 is std_logic_vector(9 downto 7);
    subtype arg2 is std_logic_vector(6 downto 4);

    constant command_mapping : command_array :=(add => 0,
                                                sub => 1,
                                                mpy => 2,
                                                div => 3,
                                                nop => 4);

    function write_instruction ( command : in t_command)
        return std_logic_vector;
------------------------------------------------------------------------
    function write_instruction (
        command     : in t_command;
        destination : in natural range 0 to 7;
        argument1   : in natural range 0 to 7;
        argument2   : in natural range 0 to 7)
    return std_logic_vector;
------------------------------------------------------------------------
    function get_instruction ( input_register : std_logic_vector )
        return integer;
------------------------------------------------------------------------
    function decode ( number : natural)
        return t_command;
------------------------------------------------------------------------
    function decode ( number : std_logic_vector)
        return t_command;
------------------------------------------------------------------------
    function get_dest ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------
    function get_arg1 ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------
    function get_arg2 ( input_register : std_logic_vector )
        return natural;
------------------------------------------------------------------------

end package testprogram_pkg;

package body testprogram_pkg is
------------------------------------------------------------------------
    function write_instruction
    (
        command     : in t_command;
        destination : in natural range 0 to 7;
        argument1   : in natural range 0 to 7;
        argument2   : in natural range 0 to 7
    )
    return std_logic_vector
    is
        variable instruction : std_logic_vector(15 downto 0);
    begin

        instruction(comm'range) := std_logic_vector(to_unsigned(t_command'pos(command) , 3));
        instruction(dest'range) := std_logic_vector(to_unsigned(destination            , 3));
        instruction(arg1'range) := std_logic_vector(to_unsigned(argument1              , 3));
        instruction(arg2'range) := std_logic_vector(to_unsigned(argument2              , 3));

        return instruction;
        
    end write_instruction;
------------------------------------------------------------------------
    function write_instruction
    (
        command : in t_command
    )
    return std_logic_vector
    is
        variable instruction : std_logic_vector(15 downto 0);
    begin

        return write_instruction(command, 3,0,1);
        
    end write_instruction;
------------------------------------------------------------------------
    function get_dest
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(dest'range)));
    end get_dest;
------------------------------------------------------------------------
    function get_arg1
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg1'range)));
    end get_arg1;
------------------------------------------------------------------------
    function get_arg2
    (
        input_register : std_logic_vector 
    )
    return natural
    is
    begin
        return to_integer(unsigned(input_register(arg2'range)));
    end get_arg2;
------------------------------------------------------------------------
    function get_instruction
    (
        input_register : std_logic_vector 
    )
    return integer
    is
    begin
        return to_integer(unsigned(input_register(comm'range)));
        
    end get_instruction;
------------------------------------------------------------------------
    function decode
    (
        number : natural
    )
    return t_command
    is
    begin
        return t_command'val(number);
    end decode;
------------------------------------------------------------------------
    function decode
    (
        number : std_logic_vector
    )
    return t_command
    is
    begin
        return decode(get_instruction(number));
    end decode;
------------------------------------------------------------------------

end package body testprogram_pkg;
------------------------------------------------------------------------
------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.testprogram_pkg.all;

entity microprogram_execution_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of microprogram_execution_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 50;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----

    signal program_counter : natural := 100;
    signal start_program : boolean := false;

    type program is array (natural range <>) of std_logic_vector(15 downto 0);
    constant test_program : program := (
        write_instruction(add),
        write_instruction(sub),
        write_instruction(mpy),
        write_instruction(div),
        write_instruction(add));

    signal test : program(test_program'range) := test_program;

    signal executed_instruction : std_logic_vector(15 downto 0) := (others => '1');
    signal decoded_command : t_command := nop;

    type realarray is array (integer range 0 to 7) of real;
    signal registers : realarray := (1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0);

    signal result : real := 0.0;

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

    stimulus : process(simulator_clock)

    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            if simulation_counter = 10 then
                program_counter <= 0;
            end if;

            if program_counter < test'high then
                program_counter <= program_counter + 1;
            end if;

            if program_counter < test'high then
                executed_instruction <= test(program_counter);
                decoded_command      <= decode(test(program_counter));
            end if;

            CASE decoded_command is
                when add =>
                    registers(get_dest(test(program_counter))) <= registers(get_arg1(test(program_counter))) + registers(get_arg2(test(program_counter)));
                when sub =>
                    registers(get_dest(test(program_counter))) <= registers(get_arg1(test(program_counter))) - registers(get_arg2(test(program_counter)));
                when mpy =>
                    registers(get_dest(test(program_counter))) <= registers(get_arg1(test(program_counter))) * registers(get_arg2(test(program_counter)));
                when div =>
                    registers(get_dest(test(program_counter))) <= registers(get_arg1(test(program_counter))) / registers(get_arg2(test(program_counter)));
                when others => --do nothing
            end CASE;

        end if; -- rising_edge
    end process stimulus;	
------------------------------------------------------------------------
end vunit_simulation;
