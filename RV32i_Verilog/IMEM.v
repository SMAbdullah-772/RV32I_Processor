// Code your design here
module imem (
    input  wire [31:0] addr,       // = PC
    output wire [31:0] instr
);
    reg [31:0] mem [0:1023];       // size to taste
    initial $readmemh("program.hex", mem);
    assign instr = mem[addr[31:2]];  // word-aligned: PC/4 as the index
endmodule