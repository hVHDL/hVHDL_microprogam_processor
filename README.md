# hHVDL microprogram processor
is a module for writing software instructions and processor design modules to process software directly in VHDL. Processor does not have a fixed structure but a desired processor can be designed using memory control and program flow control modules hence the repository has functions that simplify processor creation. 

The main features are
1. Assembler made with functions that allows writing programs in VHDL. 
2. memory control module that controls the memory read and write
3. example of a pipelined processor

an example of a low pass filter assembly program, which is tested with hardware
```vhdl
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

the repository source structure will be documented here as soon as I figure out how to use mermaid :) 

```mermaid
requirementDiagram

    requirement test_req {
    id: 1
    text: the test text.
    risk: high
    verifymethod: test
    }

    element test_entity {
    type: simulation
    }

    test_entity - satisfies -> test_req
```
