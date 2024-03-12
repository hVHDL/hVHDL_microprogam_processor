LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 
    USE ieee.NUMERIC_STD.all  ; 

    use work.ram_configuration_pkg.t_ram_data;

package memory_processor_pkg is

    type memory_processor_data_in_record is record
        memory_is_requested    : boolean;
        memory_address         : natural;
        processor_is_requested : boolean;
    end record;

    constant init_memory_processor_data_in : memory_processor_data_in_record :=
    ( false , 0 , false);

    type memory_processor_data_out_record is record
        processor_is_ready : boolean;
        data_is_ready      : boolean;
        data               : std_logic_vector(t_ram_data'range);
    end record;

------------------------------------------------------------------------
    procedure init_memory_processor (
        signal self_data_in : out memory_processor_data_in_record);
------------------------------------------------------------------------
    procedure request_processor (
        signal self_data_in : out memory_processor_data_in_record);
------------------------------------------------------------------------
    function program_is_ready (
        self_data_out : memory_processor_data_out_record)
    return boolean;
------------------------------------------------------------------------
    procedure request_data_from_ram (
        signal self_data_in : out memory_processor_data_in_record;
        address : in natural);
------------------------------------------------------------------------
    function ram_read_is_ready (
        self_data_out : memory_processor_data_out_record)
    return boolean;
------------------------------------------------------------------------
    function get_ram_data (
        self_data_out : memory_processor_data_out_record)
    return std_logic_vector;
------------------------------------------------------------------------

end package memory_processor_pkg;

package body memory_processor_pkg is

------------------------------------------------------------------------
    procedure init_memory_processor
    (
        signal self_data_in : out memory_processor_data_in_record
    ) is
    begin
        self_data_in.memory_is_requested <= false;
        self_data_in.memory_address <= 0;
        self_data_in.processor_is_requested <= false;
    end init_memory_processor;

------------------------------------------------------------------------
    procedure request_processor
    (
        signal self_data_in : out memory_processor_data_in_record
    ) is
    begin
        self_data_in.processor_is_requested <= true;
    end request_processor;
------------------------------------------------------------------------
    function program_is_ready
    (
        self_data_out : memory_processor_data_out_record
    )
    return boolean
    is
    begin
        return false;
    end program_is_ready;
------------------------------------------------------------------------
    procedure request_data_from_ram
    (
        signal self_data_in : out memory_processor_data_in_record;
        address : in natural
    ) is
    begin
        self_data_in.memory_address <= address;
        self_data_in.memory_is_requested <= true;
        
    end request_data_from_ram;
------------------------------------------------------------------------
    function ram_read_is_ready
    (
        self_data_out : memory_processor_data_out_record
    )
    return boolean
    is
    begin
        return self_data_out.data_is_ready;
    end ram_read_is_ready;
------------------------------------------------------------------------
    function get_ram_data
    (
        self_data_out : memory_processor_data_out_record
    )
    return std_logic_vector
    is
    begin
        return self_data_out.data;
    end get_ram_data;

end package body memory_processor_pkg;
------------------------------------------------------------------------
LIBRARY ieee  ; 
    USE ieee.std_logic_1164.all  ; 

    use work.memory_processor_pkg.all;
    use work.microinstruction_pkg.all;
    use work.multi_port_ram_pkg.all;
    use work.simple_processor_pkg.all;
    use work.processor_configuration_pkg.all;
    use work.float_alu_pkg.all;
    use work.float_type_definitions_pkg.all;
    use work.float_to_real_conversions_pkg.all;
    use work.float_example_program_pkg.all;

    use work.memory_processing_pkg.all;

entity memory_processor is
    generic(ram_contents : ram_array);
    port (
        clock : in std_logic	;
        data_in : in memory_processor_data_in_record;
        data_out : out memory_processor_data_out_record
    );
end entity memory_processor;


architecture rtl of memory_processor is
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

    signal float_alu : float_alu_record := init_float_alu;

begin

    memory_processor : process(clock, self, data_in)
        variable used_instruction : t_instruction;
    begin
        if rising_edge(clock) then
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

            data_out.data_is_ready <= false;
            if (not processor_is_enabled(self)) and ram_read_is_ready(ram_read_3_data_out) then
                data_out.data <= get_ram_data(ram_read_3_data_out);
                data_out.data_is_ready <= true;
            end if;

        end if; --rising_edge

        if data_in.processor_is_requested then
            request_processor(self);
        end if;

        if (not processor_is_enabled(self)) and data_in.memory_is_requested then
            request_data_from_ram(ram_read_3_data_in, data_in.memory_address);
        end if;

        data_out.processor_is_ready <= program_is_ready(self);

    end process memory_processor;	

    u_mpram : entity work.ram_read_x4_write_x1
    generic map(ram_contents)
    port map(
    clock          ,
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

end rtl;
