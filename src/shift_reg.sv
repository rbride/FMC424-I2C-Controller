`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride 
// Creation Date: 08/08/2023
// Module Name: FMC424 I2C Shift Register
// Target Device: Ultrascale RFSOC FPGA connected to FMC424 Board
// Description: 
//      Shift register used to determine a ~400ns Delay 
//////////////////////////////////////////////////////////////////////////////////
//50MHz has a clk period of 20ns, if we do a 20 FF shift register we get 400ns
module shift_reg #( 
    parameter WIDTH = 20
)(
    input wire CLK,
    input wire rst,
    input wire in,
    output reg out
);

reg [WIDTH-1:0] delay_reg;

always_ff @(posedge CLK) begin
    if(!rst) 
        delay_reg <= 0;
    else begin
        delay_reg <= {delay_reg[WIDTH-2:0], in};
    end
end

assign out = delay_reg[WIDTH-1];

endmodule