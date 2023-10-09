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
    output wire scl_t
);

reg [7:0] cnt = 8'b0;
reg scl_t_reg;
// 156.25 = 6.4ns CLK period  900ns/6.4ns = 140.625 Rising edges   1600ns/6.4ns = 250
// 250 = 0xFA   140 = 0x8D/2  MSB=1 Low Counter, MSB=0 High Counter 0xFA-1 = 0xF9 
// Divide both by two round, Low period is 0x7C (124), High Period is 0x46 (70)
always @(posedge CLK) begin
        if( cnt == {1'b0, 7'h7C}) begin
            cnt <= {1'b1, 7'h00};   //Flip Signal Bit High,Reset Counter
    
        end else if(cnt == {1'b1, 7'h46}) begin
            cnt <= {1'b0, 7'h00};   //Flip Signal Bit Low, Reset Counter
            
        end else begin
            cnt <= cnt + 1'b1;
        end
        
    end

//Assign The Signal Bit the Tristate enable Wire. 
assign scl_t = cnt[7];

endmodule
