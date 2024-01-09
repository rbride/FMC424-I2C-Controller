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
//50/50 duty means 5000ns up 5000ns down. 5000/2 = 2500 = 0x9C4
//Divider assumes a 50MHz Clock input for the I2c
module clk_gen_std_100k(
    input wire CLK,
    input wire rst,
    output wire scl_t;  // used for "O" port of IO_Buf
);

reg [12:0] cnt = 13'b1_00000_00000;
//if clk related issues try a syncronous clk this is async for literally no reason  
always_ff @(posedge CLK) begin
    if(rst) begin
        cnt <= {1'b1, 12'h000};     //Reset to Start High to math logic 
    end else if(cnt[11:0] == 12'h9C4) begin
        cnt <= {(~cnt[12]), 12'h000}; //When Reaches value, Reset Counter and Flip highest bit
    end else begin
        cnt <= cnt+1'b1;
    end
end

assign scl_t = cnt[12];

endmodule