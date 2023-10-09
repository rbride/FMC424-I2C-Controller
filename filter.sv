`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride 
// Simple Filter Based off of following
// Frequency  N     filter time (ns)
//  60        3         50
//  80        4         50 
//  100       5         50
//  150       7         47
//  200       10        50
//////////////////////////////////////////////////////////////////////////////////
// https://www.latticesemi.com/-/media/LatticeSemi/Documents/WhitePapers/HM/ImprovingNoiseImmunityforSerialInterface.ashx?document_id=50728
//require a ~50ns glitch filter time for i2c. See doc above for basically this circuit
//Will set n to 7 and use the pre-existing 156.25Mhz and will result in a 47~ NS filter time
module ff_filter#(
    parameter n = 7
)(
    input clk;
    input in;
    output reg out;
);
reg [n-1:0] shift_reg;
always @(posedge clk) begin
  shift_reg <= {shift_reg[n-2:0], in};  // shift register for input in.
  if      (&shift_reg)  out <= 1'b1;    // & = reduction AND
  else if (~|shift_reg) out <= 1'b0;    // ~| = reduction NOR
end
endmodule