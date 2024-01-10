------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.NUMERIC_STD.all  ; 
    USE ieee.std_logic_1164.all  ; 
    use ieee.math_real.all;

library vunit_lib;
context vunit_lib.vunit_context;

    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.simple_processor_pkg.all;
    use work.processor_configuration_pkg.all;
    use work.float_alu_pkg.all;
    use work.float_type_definitions_pkg.all;
    use work.float_to_real_conversions_pkg.all;

entity float_processor_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of float_processor_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 10e3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    ------------------------------------------------------------------------
    function build_sw (filter_gain : real range 0.0 to 1.0) return ram_array
    is
        variable retval : ram_array := (others => (others => '0'));

------------------------------------------------------------------------
        constant u : natural := 0;
        constant y : natural := 1;
        constant g : natural := 2;
        constant temp : natural := 3;

        constant program : program_array :=(
            write_instruction(load , 0    , 100) ,
            write_instruction(load , 1    , 101) ,
            write_instruction(load , 2    , 103) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(sub  , temp , u    , y)    ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(mpy  , temp , temp , g)    ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(add  , y    , y    , temp),
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(nop) ,
            write_instruction(save  , y    , 99)
        );

    begin

        for i in program'range loop
            retval(i) := program(i);
        end loop;

        retval(50)  := write_instruction(program_end);
        retval(100) := to_std_logic_vector(to_float(-2.0));
        retval(101) := to_std_logic_vector(to_float(2.0));
        retval(102) := to_std_logic_vector(to_float(0.1));
            
        return retval;
        
    end build_sw;
    constant ram_contents : ram_array := build_sw(0.2);

    signal processor                : simple_processor_record := init_processor;
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;
    signal ram_write_port2          : ram_write_in_record ;

    signal processor_is_ready : boolean := false;

    signal counter : natural range 0 to 7 :=7;
    signal counter2 : natural range 0 to 7 :=7;

    signal result1 : real := 0.0;
    signal result2 : real := 0.0;
    signal result3 : real := 0.0;

    signal float_alu : float_alu_record := init_float_alu;


    signal testi1 : real := 0.0;
    signal testi2 : real := 0.0;

begin

------------------------------------------------------------------------
    simtime : process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        -- check(abs(4.1 - result1) < 0.001);
        -- check(result2 > 0.45 and result2 < 0.55);
        -- check(result3 > 0.45 and result3 < 0.55);
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process simtime;	

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
        variable used_instruction : t_instruction;
------------------------------------------------------------------------     
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;
            --------------------
            create_simple_processor (
                processor                ,
                ram_read_instruction_in  ,
                ram_read_instruction_out ,
                ram_read_data_in         ,
                ram_read_data_out        ,
                ram_write_port           ,
                used_instruction);

            create_float_alu(float_alu);

        ------------------------------------------------------------------------
            --stage -1
            CASE decode(used_instruction) is
                WHEN load =>
                    request_data_from_ram(ram_read_data_in, get_sigle_argument(used_instruction));
                WHEN add => 
                    add(float_alu, 
                        to_float(processor.registers(get_arg1(used_instruction))), 
                        to_float(processor.registers(get_arg2(used_instruction))));

                        testi1 <= to_real(to_float(processor.registers(get_arg1(used_instruction))));
                        testi2 <= to_real(to_float(processor.registers(get_arg2(used_instruction))));
                WHEN sub =>
                    subtract(float_alu, 
                        to_float(processor.registers(get_arg1(used_instruction))), 
                        to_float(processor.registers(get_arg2(used_instruction))));
                WHEN mpy =>
                    multiply(float_alu, 
                        to_float(processor.registers(get_arg1(used_instruction))), 
                        to_float(processor.registers(get_arg2(used_instruction))));
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            used_instruction := processor.instruction_pipeline(0);
            --stage 0
            CASE decode(used_instruction) is

                WHEN others => -- do nothing
            end CASE;
            --stage 1
            used_instruction := processor.instruction_pipeline(1);
        ------------------------------------------------------------------------
            --stage 2
            used_instruction := processor.instruction_pipeline(2);

            CASE decode(used_instruction) is
                WHEN load =>
                    processor.registers(get_dest(used_instruction)) <= get_ram_data(ram_read_data_out);
                WHEN add | sub =>
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            --stage 3
            used_instruction := processor.instruction_pipeline(3);

            CASE decode(used_instruction) is

                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
            --stage 4
            used_instruction := processor.instruction_pipeline(4);
            CASE decode(used_instruction) is
                WHEN mpy =>
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------
        --stage 5
            used_instruction := processor.instruction_pipeline(5);
            CASE decode(used_instruction) is
                WHEN mpy =>
                    processor.registers(get_dest(used_instruction)) <= to_std_logic_vector(get_multiplier_result(float_alu));
                WHEN add => 
                    processor.registers(get_dest(used_instruction)) <= to_std_logic_vector(get_add_result(float_alu));
                WHEN save =>
                    write_data_to_ram(ram_write_port, get_sigle_argument(used_instruction), processor.registers(get_dest(used_instruction)));
                WHEN others => -- do nothing
            end CASE;
        ------------------------------------------------------------------------

        ------------------------------------------------------------------------
        -- test signals
        ------------------------------------------------------------------------
            if add_is_ready(float_alu) then
                result1 <= to_real(get_add_result(float_alu));
            end if;

            if multiplier_is_ready(float_alu) then
                result2 <= to_real(get_multiplier_result(float_alu));
            end if;
            if simulation_counter mod 60 = 0 then
                request_processor(processor);
            end if;
            processor_is_ready <= program_is_ready(processor);
            if program_is_ready(processor) then
                counter <= 0;
                counter2 <= 0;
            end if;
            if counter < 7 then
                counter <= counter +1;
            end if;

            CASE counter is
                WHEN 0 => request_data_from_ram(ram_read_data_in, 99);
                WHEN others => --do nothing
            end CASE;
            if not processor_is_enabled(processor) then
                if ram_read_is_ready(ram_read_data_out) then
                    counter2 <= counter2 + 1;
                    CASE counter2 is
                        -- WHEN 0 => result1 <= to_real(get_ram_data(ram_read_data_out),19);
                        -- WHEN 1 => result2 <= to_real(get_ram_data(ram_read_data_out),19);
                        WHEN 0 => result3 <= to_real(to_float(get_ram_data(ram_read_data_out)));
                        WHEN others => -- do nothing
                    end CASE; --counter2
                end if;
            end if;

        end if; -- rising_edge
    end process stimulus;	

------------------------------------------------------------------------
    u_mpram : entity work.ram_read_x2_write_x1
    generic map(ram_contents)
    port map(
    simulator_clock          ,
    ram_read_instruction_in  ,
    ram_read_instruction_out ,
    ram_read_data_in         ,
    ram_read_data_out        ,
    ram_write_port);
------------------------------------------------------------------------
end vunit_simulation;
