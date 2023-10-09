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
//Input Clock is the 156.25MHZ PLL sourced from FPGA
// IOBUF
//      T -|
//         |
//  I------|>>----+---[I/O PIN]
//                |
//  O-----<<|-----+

module clk_gen(
    input wire CLK,         
    input wire scl_out,
    input wire scl_t,
    inout wire SCL_PIN
);
reg en_t;
reg [8:0] cnt = 9'b0;

// 156.25 = 6.4ns CLK period
// 900ns/6.4ns = 140.625 Rising edges   1600ns/6.4ns = 250
// 250 = 0xFA   140 = 0x8D  MSB=1 Low Counter, MSB=0 High Counter 0xFA-1 = 0xF9
always @(posedge CLK) begin
    if( cnt && {1'b1, 8'hF9}) begin
        en_t <= 1'b0;   //Low
        cnt = {1'b0, 8'h00};
    end else if(cnt && {0'b0, 8'h8D}) begin
        en_t <= 1'b1;   //High
        cnt = {1'b1, 8'h00};
    end else begin
        cnt <= cnt+1'b1;
    end
end

assign SCL_PIN = en_t ? 1'bZ : 1'b0;

endmodule