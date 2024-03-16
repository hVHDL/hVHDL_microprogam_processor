
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

    use work.memory_processing_pkg.all;
    use work.float_assembler_pkg.all;
    use work.microinstruction_pkg.all;

entity lcr_3ph_tb is
  generic (runner_cfg : string);
end;

architecture vunit_simulation of lcr_3ph_tb is

    constant clock_period      : time    := 1 ns;
    constant simtime_in_clocks : integer := 1e4/3;
    
    signal simulator_clock     : std_logic := '0';
    signal simulation_counter  : natural   := 0;
    -----------------------------------
    -- simulation specific signals ----
    ------------------------------------------------------------------------

------------------------------------------------------------------------
    signal i1 : real := 0.0;
    signal i2 : real := 0.0;
    signal i3 : real := 0.0;
    signal uc1 : real := 0.0;
    signal uc2 : real := 0.0;
    signal uc3 : real := 0.0;

    constant init_phase : real := 0.4;
    signal phase : real := 0.7*2.0*math_pi;

    signal u1 : real := 0.0;
    signal u2 : real := 0.0;
    signal u3 : real := 0.0;

    signal simtime : real := 0.0;
    constant timestep : real := 100.0e-6;

    signal r : real := 0.65;
    signal l : real := 0.01;
    signal c : real := 0.01;
    signal sequencer : natural := 0;

    constant input_voltage_addr : natural := 89;
    constant voltage_addr       : natural := 90;
    constant current_addr       : natural := 91;
    constant c_addr             : natural := 92;
    constant l_addr             : natural := 93;
    constant r_addr             : natural := 94;
    constant mac1_addr          : natural := 95;
    constant mac2_addr          : natural := voltage_addr;
    constant sub1_addr          : natural := 97;

    function build_lcr_sw (filter_gain : real range 0.0 to 1.0; u_address, y_address, g_address, temp_address : natural) return ram_array
    is

        constant program : program_array :=(
            pipelined_block(
                program_array'(
                write_instruction(mpy_add, mac1_addr, current_addr, r_addr, voltage_addr),
                write_instruction(mpy_add, mac2_addr, current_addr, c_addr, voltage_addr)
                )
            ) &
            pipelined_block(
                write_instruction(sub, sub1_addr, input_voltage_addr, mac1_addr)
            ) &
            pipelined_block(
                write_instruction(mpy_add, current_addr, sub1_addr, l_addr, current_addr)
            ) &
            write_instruction(program_end));
        ------------------------------
        variable retval : ram_array := (others => (others => '0'));
    begin
        for i in program'range loop
            retval(i) := program(i);
        end loop;
        retval(input_voltage_addr) := to_std_logic_vector(to_float(1.0));
        retval(voltage_addr      ) := to_std_logic_vector(to_float(0.0));
        retval(current_addr      ) := to_std_logic_vector(to_float(0.0));
        retval(c_addr            ) := to_std_logic_vector(to_float(0.01));
        retval(l_addr            ) := to_std_logic_vector(to_float(0.01));
        retval(r_addr            ) := to_std_logic_vector(to_float(0.5));
        retval(mac1_addr         ) := to_std_logic_vector(to_float(0.0));
        retval(mac2_addr         ) := to_std_logic_vector(to_float(0.0));
        retval(sub1_addr         ) := to_std_logic_vector(to_float(0.0));

        return retval;
    end build_lcr_sw;

------------------------------------------------------------------------
    constant ram_contents : ram_array := build_lcr_sw(0.05 , 0 , 0 , 0, 0);
------------------------------------------------------------------------

    signal self                     : simple_processor_record := init_processor;
    signal ram_read_instruction_in  : ram_read_in_record  := (0, '0');
    signal ram_read_instruction_out : ram_read_out_record ;
    signal ram_read_data_in         : ram_read_in_record  := (0, '0');
    signal ram_read_data_out        : ram_read_out_record ;
    signal ram_read_2_data_in       : ram_read_in_record  := (0, '0');
    signal ram_read_2_data_out      : ram_read_out_record ;
    signal ram_read_3_data_in       : ram_read_in_record  := (0, '0');
    signal ram_read_3_data_out      : ram_read_out_record ;
    signal ram_write_port           : ram_write_in_record ;

    signal processor_is_ready : boolean := false;

    signal counter : natural range 0 to 7 :=7;
    signal counter2 : natural range 0 to 7 :=7;

    signal result1 : real := 0.0;
    signal result2 : real := 0.0;
    signal result3 : real := 0.0;

    signal float_alu : float_alu_record := init_float_alu;


    signal testi1 : real := 0.0;
    signal testi2 : real := 0.0;

    signal usum : real := 0.0;


begin

------------------------------------------------------------------------
    process
    begin
        test_runner_setup(runner, runner_cfg);
        wait for simtime_in_clocks*clock_period;
        test_runner_cleanup(runner); -- Simulation ends here
        wait;
    end process;

    simulator_clock <= not simulator_clock after clock_period/2.0;
------------------------------------------------------------------------

    stimulus : process(simulator_clock)
        variable used_instruction : t_instruction;
        variable mac1 : real := 0.0;
        variable sub1 : real := 0.0;
        variable mac2 : real := 0.0;
        variable mac3 : real := 0.0;
        variable ul1 : real := 0.0;
        type realarray is array (natural range <>) of real;
        variable add : realarray(0 to 15) := (others => 0.0);
        variable sub : realarray(0 to 15) := (others => 0.0);
        variable mult_add : realarray(0 to 15) := (others => 0.0);
    begin
        if rising_edge(simulator_clock) then
            simulation_counter <= simulation_counter + 1;

            -- CASE sequencer is
            --     WHEN 0 => 
            --         mac1 := current * r + voltage;
            --         mac2 := current * c + voltage;
            --
            --         sub1 := input_voltage - mac1;
            --
            --         mac3 := sub1 * l + current;
            --
            --         current   <= mac3;
            --         voltage   <= mac2;
            --         sequencer <= sequencer + 1;
            --     WHEN others => -- do nothing
            -- end CASE;
            CASE sequencer is
                WHEN 1 => 

                    -- pipelined block 1
                    add(0) := u1 + u2;
                    add(1) := u2 + u3;
                    add(2) := u1 + u3;

                    add(3) := u1 + u2;
                    add(4) := u2 + u3;
                    add(5) := u1 + u3;

                    add(6) := uc1 + uc2;
                    add(7) := uc2 + uc3;
                    add(8) := uc1 + uc3;

                    add(9)  := uc1 + uc2;
                    add(10) := uc2 + uc3;
                    add(11) := uc1 + uc3;

                    add(12) := i1 + i2;
                    add(13) := i2 + i3;
                    add(14) := i1 + i3;

                    -- pipelined block 2
                    sub(0) := u1 - add(1);
                    sub(1) := u2 - add(2);
                    sub(2) := u3 - add(0);

                    sub(3) := uc1 - add(7);
                    sub(4) := uc2 - add(8);
                    sub(5) := uc3 - add(6);

                    sub(6) := i1 - add(13);
                    sub(7) := i2 - add(14);
                    sub(8) := i3 - add(12);

                    i1   <= (sub(0) - (sub(6))/2.0*r -(sub(3))) * l/2.0 + i1;
                    i2   <= (sub(1) - (sub(7))/2.0*r -(sub(4))) * l/2.0 + i2;
                    i3   <= (sub(2) - (sub(8))/2.0*r -(sub(5))) * l/2.0 + i3;

                    -- i1   <= ((+u1-u2-u3) - (+i1-i2-i3 )/2.0*r -((+uc1-uc2-uc3))) * l/2.0 + i1;
                    -- i2   <= ((-u1+u2-u3) - (-i1+i2-i3 )/2.0*r -((-uc1+uc2-uc3))) * l/2.0 + i2;
                    -- i3   <= ((-u1-u2+u3) - (-i1-i2+i3 )/2.0*r -((-uc1-uc2+uc3))) * l/2.0 + i3;
                WHEN 0 => 
                    uc1   <= ((+i1-i2-i3 ) ) * c/2.0 + uc1;
                    uc2   <= ((-i1+i2-i3 ) ) * c/2.0 + uc2;
                    uc3   <= ((-i1-i2+i3 ) ) * c/2.0 + uc3;

                    -- uc1   <= ((+i1-i2-i3 ) ) * c/2.0 + uc1;
                    -- uc2   <= ((-i1+i2-i3 ) ) * c/2.0 + uc2;
                    -- uc3   <= ((-i1-i2+i3 ) ) * c/2.0 + uc3;

                    simtime <= simtime + timestep;
                    sequencer <= sequencer + 1;
                WHEN others => -- do nothing
            end CASE;

            CASE sequencer is
                WHEN 0 =>
                    phase <= (phase + 2.0*math_pi/250.0) mod (2.0*math_pi);
                WHEN 1 =>
                    u1 <= sin((phase+2.0*math_pi/3.0) mod (2.0*math_pi));
                    u2 <= sin(phase);
                    u3 <= sin((phase-2.0*math_pi/3.0) mod (2.0*math_pi));

                    usum <= uc1+uc2+uc3;
                WHEN others => -- do nothing
            end CASE;

            if sequencer = 1 then
                sequencer <= 0;
            end if;

            --------------------
            create_simple_processor (
                self                     ,
                ram_read_instruction_in  ,
                ram_read_instruction_out ,
                ram_read_data_in         ,
                ram_read_data_out        ,
                ram_write_port           ,
                used_instruction);

            init_ram_read(ram_read_2_data_in);
            init_ram_read(ram_read_3_data_in);
            create_float_alu(float_alu);

            create_memory_process_pipeline(
             self                     ,
             float_alu                ,
             used_instruction         ,
             ram_read_instruction_out ,
             ram_read_data_in         ,
             ram_read_data_out        ,
             ram_read_2_data_in       ,
             ram_read_2_data_out      ,
             ram_read_3_data_in       ,
             ram_read_3_data_out      ,
             ram_write_port          );


        ------------------------------------------------------------------------
        ------------------------------------------------------------------------
            ------------------------------------------------------------------------
            -- test signals
            ------------------------------------------------------------------------
            if simulation_counter mod 61 = 0 then
                request_processor(self);
            end if;
            processor_is_ready <= processor_is_enabled(self);
            if program_is_ready(self) then
                counter <= 0;
                counter2 <= 0;
                sequencer <= 0;
            end if;
            if counter < 7 then
                counter <= counter +1;
            end if;

            CASE counter is
                WHEN 0 => request_data_from_ram(ram_read_data_in, voltage_addr);
                WHEN 1 => request_data_from_ram(ram_read_data_in, current_addr);
                WHEN others => --do nothing
            end CASE;
            if not processor_is_enabled(self) then
                if ram_read_is_ready(ram_read_data_out) then
                    counter2 <= counter2 + 1;
                    CASE counter2 is
                        WHEN 0 => result3 <= to_real(to_float(get_ram_data(ram_read_data_out)));
                        WHEN 1 => result2 <= to_real(to_float(get_ram_data(ram_read_data_out)));
                        WHEN others => -- do nothing
                    end CASE; --counter2
                end if;
            end if;

        end if; -- rising_edge
    end process stimulus;	

------------------------------------------------------------------------
    u_mpram : entity work.ram_read_x4_write_x1
    generic map(ram_contents)
    port map(
    simulator_clock          ,
    ram_read_instruction_in  ,
    ram_read_instruction_out ,
    ram_read_data_in         ,
    ram_read_data_out        ,
    ram_read_2_data_in       ,
    ram_read_2_data_out      ,
    ram_read_3_data_in       ,
    ram_read_3_data_out      ,
    ram_write_port);
------------------------------------------------------------------------
end vunit_simulation;
