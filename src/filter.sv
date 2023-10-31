`timescale 1ns / 1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride 
// Creation Date: 08/08/2023
// Module Name: FMC424 I2C Noise Filter
// Target Device: Ultrascale RFSOC FPGA connected to FMC424 Board
// Description: 
//    Simple Noise/ Glitch Filter to create stable SCL and SDA inputs to the FSM
//////////////////////////////////////////////////////////////////////////////////
// https://www.latticesemi.com/-/media/LatticeSemi/Documents/WhitePapers/HM/ImprovingNoiseImmunityforSerialInterface.ashx?document_id=50728
// require a ~50ns glitch filter time for i2c. See doc above for basically this circuit
// Will set n to 7 and use the pre-existing 156.25Mhz and will result in a 47~ NS filter time
module ff_filter#(
    parameter STAGES = 7
)(
    input wire clk,
    input wire _in,
    output reg _out
);
reg [STAGES-1:0] shift_reg;
always @(posedge clk) begin
  shift_reg <= {shift_reg[STAGES-2:0], _in};  // shift register for input in.
  if      (&shift_reg) // & = reduction AND
    _out <= 1'b1;    
  else if (~|shift_reg) // ~| = reduction NOR
    _out <= 1'b0;    
end
endmodule