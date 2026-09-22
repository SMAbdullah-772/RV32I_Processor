// Code your design here

module Program_counter(
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] pc_in,   // next PC in, from top-sheet mux
    output reg  [31:0] pc_out
);
    always @(posedge clk) begin
        if (rst)
            pc_out <= 32'd0;
        else
            pc_out <= pc_in;
    end
endmodule