# vhdl microprogram processor
VHDL module for running instructions from memory with processor. Processor does not have a fixed structure but there are functions for reading and writing program and data ram hence the repository has functions that simplify processor creation. 

The main features are
1. Assembler made with functions that allows writing programs in VHDL. 
2. memory control module that controls the memory read and write
3. example of a pipelined processor

an example of a low pass filter assembly program, which is tested with hardware
```
    function get_pipelined_low_pass_filter return program_array is
        constant y    : integer := 0;
        constant u    : integer := 1;
        constant temp : integer := 2;
        constant g    : integer := 7;

        constant lpf : program_array := (
            write_instruction(sub          , temp , u    , y)    ,
            write_instruction(nop)                               ,
            write_instruction(nop)                               ,
            write_instruction(mpy          , temp , temp , g)    ,
            write_instruction(nop)                               ,
            write_instruction(nop)                               ,
            write_instruction(nop)                               ,
            write_instruction(add          , y    , y    , temp) ,
            write_instruction(nop)                               ,
            write_instruction(nop)                               ,
            write_instruction(ready)                             ,
            write_instruction(program_end)                       ,
            write_instruction(program_end)                       ,
            write_instruction(program_end)
        );

    begin

        return lpf;
        
    end get_pipelined_low_pass_filter;
```
