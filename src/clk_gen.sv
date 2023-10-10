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
///  Standard 400KHz Clk Ver.  ///
//////////////////////////////////
module clk_gen_std(
    input wire CLK, //156.25MHz
    output wire scl_t
);

reg [9:0] cnt = 10'b1_000_000_000;

always @(posedge CLK) begin
    if(cnt[8:0] == 8'h186 ) 
        cnt <= {!cnt[9], 9'b000_000_000};
    else
        cnt <= cnt + 1'b1;
end

assign scl_t = cnt[9];

endmodule
//////////////////////////////////
/// Non Std Duty Cycle Version ///
//////////////////////////////////
// 156.25 = 6.4ns CLK period  900ns/6.4ns = 140.625 Rising edges   1600ns/6.4ns = 250
// 250 = 0xFA   140 = 0x8C  MSB=0 Low Counter, MSB=1 High Counter 0xFA-1 = 0xF9 gives perfect sim result 
// 140 results in more time high, .9024ns. and 399.616369KHz clk, 139 results in less .896ns, and 400.641026Khz, 
// Faster was chosen and assumed the Repeater would filter it out.
module clk_gen_sft(
    input wire CLK,         
    output wire scl_t
);

reg [8:0] cnt = 9'b0000000000;

always @(posedge CLK) begin
    if( cnt == {1'b0, 8'hF9}) begin
        cnt <= {1'b1, 8'b00000000};   //Flip Signal Bit High,Reset Counter

    end else if(cnt == {1'b1, 8'h8B}) begin 
        cnt <= {1'b0, 8'b00000000};   //Flip Signal Bit Low, Reset Counter
        
    end else begin
        cnt <= cnt + 1'b1;
    end
end

    //Assign The Signal Bit the Tristate enable Wire. 
assign scl_t = cnt[8];

endmodule