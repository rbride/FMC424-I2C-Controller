`timescale 1ns/1ps
`default_nettype none
//////////////////////////////////////////////////////////////////////////////////
// Engineer: Ryan Bride 
// Create Date: 08/08/2023 
// Module Name: FMC424 I2C Clock Generator
// Target Devices: Ultrascale RFSOC FPGA Connected to FMC424 Board 
// Description: 
//      I2C Clock Generator for FMC242 I2C Controller. 
//      For more details see the Project Readme on Github
//////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////
///  Standard 100KHz Clk Ver.  ///
//////////////////////////////////
//50/50 duty means 5000ns up 5000ns down. 5000/20 = 250 = 0xFA
//Divider assumes a 50MHz Clock input for the I2c
module clk_gen_std_100k(
    input wire CLK,
    input wire rst,
    output wire scl_i  // used for "O" port of IO_Buf
);

reg [8:0] cnt = 9'b1_0000_0000;
//if clk related issues try a syncronous clk this is sync for literally no reason  
always_ff @(posedge CLK) begin
    if(!rst) begin
        cnt <= {1'b1, 8'h00};     //Reset to Start High to math logic 
    end else if(cnt[7:0] == 8'hFA) begin
        cnt <= {(~cnt[8]), 8'h00}; //When Reaches value, Reset Counter and Flip highest bit
    end else begin
        cnt <= cnt + 1'b1;
    end
end

assign scl_i = cnt[8];

endmodule