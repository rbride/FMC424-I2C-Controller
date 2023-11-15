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
// Same as Below, actually generates a 400.641026Khz Clock, can slow to 398.596939
// if you change C2 to C3, chose the faster because its closer, and assume it wouldn't matter
module clk_gen_std_400k(
    input wire CLK, //156.25MHz
    output wire scl_t
);

reg [8:0] cnt = 9'b1_000_000_000;

always @(posedge CLK) begin
    if(cnt[7:0] == 8'hC2 ) 
        cnt <= {(~cnt[8]), 8'b0000_0000};
    else
        cnt <= cnt + 1'b1;
end

assign scl_t = cnt[8];

endmodule

//////////////////////////////////
/// Non Std Duty Cycle Version ///
//////////////////////////////////
// 156.25 = 6.4ns CLK period  900ns/6.4ns = 140.625 Rising edges   1600ns/6.4ns = 250
// 250 = 0xFA   140 = 0x8C  MSB=0 Low Counter, MSB=1 High Counter 0xFA-1 = 0xF9 gives perfect sim result 
// 140 results in more time high, .9024ns. and 399.616369KHz clk, 139 results in less .896ns, and 400.641026Khz, 
// Faster was chosen and assumed the Repeater would filter it out.
module clk_gen_sft_400k(
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

//After Contact with Abaco, the CLPD on the Board has been revealed to not support Fast mode and only support
//100KHz, I am only going to make the standard duty cycle 100Khz One as of now
//////////////////////////////////
///  Standard 100KHz Clk Ver.  ///
//////////////////////////////////
//50/50 duty means 5000ns up 5000ns down. 5000/6.4 = 781.25 = 0x30D
//0x30E generates 99.7765006Khz clk, 0x30D generates 102.257853
module clk_gen_std_100k(
    input wire CLK,
    input wire en, //Reset is called during start, and we want to start low
    output wire scl_t
);
//Start With 0ff 
reg en_last = 1'b0; 
reg [10:0] cnt = 11'b1_00000_00000;
  
always @(posedge CLK) begin
    if (en != 1) begin
      	if(en_last) begin
            cnt[10] <= 1'b0; //We should just need to set the first bit not all 
        end else begin 
            //The CLK gen is off we are inbetween sends of for some other reason we don't need it
            //At the moment, Idk this is trial and error.
            cnt <= 11'b0_00000_00000;
        end
    end else begin
        if(cnt[9:0] == 10'h30E)
            cnt <= {(~cnt[10]), 10'b00000_00000};
        else
            cnt <= cnt + 1'b1;
    end

    //Set en_last so that it resets so every time we turn on and off we reset the entire register
    en_last <= en;

end 

assign scl_t = cnt[10];

endmodule